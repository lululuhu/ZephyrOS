#!/usr/bin/env bash
# ============================================================================
# ZephyrOS GSI Build — AOSP 源码缓存管理
# ----------------------------------------------------------------------------
# 用法:
#   cache_source.sh restore <aosp_root> <cache_tag>
#   cache_source.sh save    <aosp_root> <cache_tag>
#
# 原理:
#   GitHub Actions runner 是临时的, 每次提交都重新同步 79GB 源码浪费 30-40 分钟。
#   本脚本将同步好的源码打包上传到 GitHub Release, 下次运行直接下载解压,
#   节省大量时间。
#
# 存储方案:
#   - GitHub Release (tag: aosp-cache-13) 存储源码分片压缩包
#   - 单文件 1.5GB 分片 (GitHub Release 限制 2GB/文件)
#   - 压缩后约 10-15GB (原始 ~25GB 去除 .repo/.git)
# ============================================================================
set -euo pipefail

ACTION="${1:-}"
AOSP_ROOT="${2:-}"
CACHE_TAG="${3:-aosp-cache-13}"

# GitHub Release 单文件大小限制 (留 500MB 余量)
CHUNK_SIZE_MB=1500

if [ -z "$ACTION" ] || [ -z "$AOSP_ROOT" ]; then
    echo "Usage: cache_source.sh <restore|save> <aosp_root> [cache_tag]"
    exit 1
fi

# 检查 gh CLI 是否可用
check_gh() {
    if ! command -v gh &>/dev/null; then
        echo "[ERROR] gh CLI not found. Install: apt-get install gh"
        return 1
    fi
    if [ -z "${GH_TOKEN:-}" ] && [ -z "${GITHUB_TOKEN:-}" ]; then
        echo "[ERROR] GH_TOKEN or GITHUB_TOKEN not set. Cannot authenticate."
        return 1
    fi
    return 0
}

# =========================================================================
# RESTORE: 从 GitHub Release 下载缓存的 AOSP 源码
# =========================================================================
restore_cache() {
    echo "=============================================="
    echo "[CACHE] Attempting to restore AOSP source from cache..."
    echo "[CACHE] Cache tag: $CACHE_TAG"
    echo "=============================================="

    if ! check_gh; then
        echo "[CACHE] gh CLI not available, skipping cache restore."
        return 1
    fi

    # 检查 release 是否存在
    if ! gh release view "$CACHE_TAG" --repo "${GITHUB_REPOSITORY:-}" &>/dev/null; then
        echo "[CACHE] No cache release found (tag: $CACHE_TAG). Will sync from source."
        return 1
    fi

    echo "[CACHE] Cache release found! Downloading..."

    # 下载所有分片
    DOWNLOAD_DIR="/tmp/aosp_cache_dl"
    mkdir -p "$DOWNLOAD_DIR"

    if ! gh release download "$CACHE_TAG" \
        --repo "${GITHUB_REPOSITORY:-}" \
        --dir "$DOWNLOAD_DIR" \
        --pattern "aosp_part_*" \
        --clobber; then
        echo "[CACHE] Download failed. Will sync from source."
        rm -rf "$DOWNLOAD_DIR"
        return 1
    fi

    # 检查下载的文件
    PART_COUNT=$(ls "$DOWNLOAD_DIR"/aosp_part_* 2>/dev/null | wc -l)
    if [ "$PART_COUNT" -eq 0 ]; then
        echo "[CACHE] No cache parts found in release."
        rm -rf "$DOWNLOAD_DIR"
        return 1
    fi

    echo "[CACHE] Downloaded $PART_COUNT part(s)."

    # 合并分片 (按数字顺序排序)
    echo "[CACHE] Merging parts..."
    COMBINED="$DOWNLOAD_DIR/aosp_source.tar.gz"
    ls "$DOWNLOAD_DIR"/aosp_part_* | sort -V | xargs cat > "$COMBINED"

    # 解压到 AOSP 目录
    echo "[CACHE] Extracting to $AOSP_ROOT ..."
    mkdir -p "$AOSP_ROOT"
    if tar -xzf "$COMBINED" -C "$AOSP_ROOT" --strip-components=1 2>/dev/null || \
       tar -xzf "$COMBINED" -C "$AOSP_ROOT"; then
        echo "[CACHE] Extract successful!"
    else
        echo "[CACHE] Extract failed. Will sync from source."
        rm -rf "$DOWNLOAD_DIR" "$AOSP_ROOT"
        return 1
    fi

    # 清理
    rm -rf "$DOWNLOAD_DIR"

    echo "[CACHE] AOSP source restored from cache."
    echo "=============================================="
    df -h "$AOSP_ROOT"
    return 0
}

# =========================================================================
# SAVE: 将同步好的 AOSP 源码流式打包上传到 GitHub Release
#       使用命名管道 (FIFO) 避免创建完整 tarball, 只占用 ~1.5GB 缓冲
# =========================================================================
save_cache() {
    echo "=============================================="
    echo "[CACHE] Saving AOSP source to cache..."
    echo "[CACHE] Cache tag: $CACHE_TAG"
    echo "=============================================="

    if ! check_gh; then
        echo "[CACHE] gh CLI not available, skipping cache save."
        return 0
    fi

    if [ ! -d "$AOSP_ROOT" ]; then
        echo "[CACHE] AOSP root not found: $AOSP_ROOT"
        return 1
    fi

    # 检查是否已经有缓存 (避免重复上传)
    if gh release view "$CACHE_TAG" --repo "${GITHUB_REPOSITORY:-}" &>/dev/null; then
        ASSET_COUNT=$(gh release view "$CACHE_TAG" --repo "${GITHUB_REPOSITORY:-}" --json assets --jq '.assets | length' 2>/dev/null || echo "0")
        if [ "$ASSET_COUNT" -gt 0 ]; then
            echo "[CACHE] Cache release already exists with $ASSET_COUNT asset(s). Skipping upload."
            echo "[CACHE] To force refresh, delete the release first: gh release delete $CACHE_TAG"
            return 0
        fi
    fi

    echo "[CACHE] Source size:"
    du -sh "$AOSP_ROOT" 2>/dev/null || true
    echo "[CACHE] Disk free before:"
    df -h / | tail -1

    # 先创建空 release
    echo "[CACHE] Creating release $CACHE_TAG ..."
    if gh release view "$CACHE_TAG" --repo "${GITHUB_REPOSITORY:-}" &>/dev/null; then
        gh release delete "$CACHE_TAG" --repo "${GITHUB_REPOSITORY:-}" --yes 2>/dev/null || true
        git push origin ":refs/tags/$CACHE_TAG" 2>/dev/null || true
        sleep 5  # 等待 GitHub 删除完成
    fi

    if ! gh release create "$CACHE_TAG" \
        --repo "${GITHUB_REPOSITORY:-}" \
        --title "AOSP Source Cache" \
        --notes "Pre-synced AOSP source for ZephyrOS CI. $(date -u +"%Y-%m-%d %H:%M:%S UTC")" \
        --draft 2>/dev/null; then
        echo "[CACHE] Failed to create release."
        return 0
    fi

    # 流式打包: tar → 命名管道 → dd 分片 → 逐个上传并删除
    # 避免在磁盘上创建完整 tarball (79GB 源码压缩后约 30-40GB, 磁盘不够)
    echo "[CACHE] Streaming tar + split + upload (max ~1.5GB buffer)..."
    FIFO="/tmp/aosp_cache_fifo"
    mkfifo "$FIFO"

    # 后台 tar: 从 AOSP_ROOT 打包输出到 FIFO
    tar -czf "$FIFO" \
        -C "$AOSP_ROOT" \
        --exclude='.repo' \
        --exclude='.git' \
        --exclude='out' \
        . 2>/dev/null &
    TAR_PID=$!

    PART_NUM=0
    CHUNK_PREFIX="aosp_part_"
    CHUNK_FILE="/tmp/${CHUNK_PREFIX}chunk"
    CHUNK_BYTES=$((CHUNK_SIZE_MB * 1024 * 1024))
    FAILED=false

    while true; do
        # 从 FIFO 读取一个分片 (1.5GB)
        dd if="$FIFO" of="$CHUNK_FILE" bs=64K count=$((CHUNK_BYTES / 65536)) 2>/dev/null
        ACTUAL_SIZE=$(stat -c%s "$CHUNK_FILE" 2>/dev/null || echo 0)

        if [ "$ACTUAL_SIZE" -eq 0 ]; then
            rm -f "$CHUNK_FILE"
            break
        fi

        # 重命名为唯一名称以便 restore 时识别
        PART_NAME="${CHUNK_PREFIX}$(printf '%03d' $PART_NUM)"
        PART_FILE="/tmp/${PART_NAME}"
        mv "$CHUNK_FILE" "$PART_FILE"

        echo "[CACHE] Part $PART_NUM ($PART_NAME): $(numfmt --to=iec $ACTUAL_SIZE) — uploading..."
        if ! gh release upload "$CACHE_TAG" "$PART_FILE" \
            --repo "${GITHUB_REPOSITORY:-}" \
            --clobber 2>/dev/null; then
            echo "[CACHE] Upload failed for part $PART_NUM. Aborting."
            FAILED=true
            rm -f "$PART_FILE"
            break
        fi

        rm -f "$PART_FILE"
        PART_NUM=$((PART_NUM + 1))
    done

    # 等待 tar 完成
    wait $TAR_PID 2>/dev/null || true
    rm -f "$FIFO" "$CHUNK_FILE" /tmp/"${CHUNK_PREFIX}"* 2>/dev/null || true

    if [ "$FAILED" = "true" ]; then
        echo "[CACHE] Cache save incomplete. Will retry on next run."
        return 0
    fi

    echo "[CACHE] AOSP source cached successfully! ($PART_NUM parts)"
    echo "[CACHE] Next CI run will restore from cache, skipping repo sync."
    echo "=============================================="
    return 0
}

# =========================================================================
# MAIN
# =========================================================================
case "$ACTION" in
    restore)
        restore_cache
        ;;
    save)
        save_cache
        ;;
    *)
        echo "Usage: cache_source.sh <restore|save> <aosp_root> [cache_tag]"
        exit 1
        ;;
esac