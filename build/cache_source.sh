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
        --pattern "aosp_*.tar.gz.*" \
        --clobber; then
        echo "[CACHE] Download failed. Will sync from source."
        rm -rf "$DOWNLOAD_DIR"
        return 1
    fi

    # 检查下载的文件
    PART_COUNT=$(ls "$DOWNLOAD_DIR"/aosp_*.tar.gz.* 2>/dev/null | wc -l)
    if [ "$PART_COUNT" -eq 0 ]; then
        echo "[CACHE] No cache parts found in release."
        rm -rf "$DOWNLOAD_DIR"
        return 1
    fi

    echo "[CACHE] Downloaded $PART_COUNT part(s)."

    # 合并分片
    echo "[CACHE] Merging parts..."
    COMBINED="$DOWNLOAD_DIR/aosp_source.tar.gz"
    cat "$DOWNLOAD_DIR"/aosp_*.tar.gz.* > "$COMBINED"

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
# SAVE: 将同步好的 AOSP 源码打包上传到 GitHub Release
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

    echo "[CACHE] Creating tarball (excluding .repo and .git)..."
    echo "[CACHE] Source size before compression:"
    du -sh "$AOSP_ROOT" 2>/dev/null || true

    TARBALL="/tmp/aosp_source.tar.gz"
    echo "[CACHE] This may take 15-30 minutes (compressing ~25GB)..."
    tar -czf "$TARBALL" \
        -C "$AOSP_ROOT" \
        --exclude='.repo' \
        --exclude='.git' \
        --exclude='out' \
        . 2>/dev/null || {
        echo "[CACHE] tar failed, trying without compression for speed..."
        rm -f "$TARBALL"
        TARBALL="/tmp/aosp_source.tar"
        tar -cf "$TARBALL" \
            -C "$AOSP_ROOT" \
            --exclude='.repo' \
            --exclude='.git' \
            --exclude='out' \
            . 2>/dev/null
    }

    TARBALL_SIZE=$(du -sh "$TARBALL" 2>/dev/null | awk '{print $1}')
    echo "[CACHE] Tarball size: $TARBALL_SIZE"

    # 分片 (每个 1.5GB, 留 500MB 余量给 GitHub 2GB 限制)
    echo "[CACHE] Splitting into ${CHUNK_SIZE_MB}MB chunks..."
    SPLIT_DIR="/tmp/aosp_cache_parts"
    mkdir -p "$SPLIT_DIR"
    split -b "${CHUNK_SIZE_MB}M" -d "$TARBALL" "$SPLIT_DIR/aosp_$(date +%Y%m%d).tar.gz."
    PART_COUNT=$(ls "$SPLIT_DIR"/ | wc -l)
    echo "[CACHE] Created $PART_COUNT part(s)."

    # 创建或更新 release
    echo "[CACHE] Creating/updating release $CACHE_TAG ..."
    if gh release view "$CACHE_TAG" --repo "${GITHUB_REPOSITORY:-}" &>/dev/null; then
        # 删除旧 release 和 tag
        gh release delete "$CACHE_TAG" --repo "${GITHUB_REPOSITORY:-}" --yes 2>/dev/null || true
        # 删除旧 tag (可能需要 force push)
        git push origin ":refs/tags/$CACHE_TAG" 2>/dev/null || true
    fi

    gh release create "$CACHE_TAG" \
        --repo "${GITHUB_REPOSITORY:-}" \
        --title "AOSP Source Cache" \
        --notes "Pre-synced AOSP source for ZephyrOS CI. $(date -u +"%Y-%m-%d %H:%M:%S UTC")" \
        "$SPLIT_DIR"/* 2>/dev/null || {
        echo "[CACHE] Failed to create release. Uploading may have timed out."
        echo "[CACHE] You can manually upload later."
        rm -rf "$TARBALL" "$SPLIT_DIR"
        return 0
    }

    # 清理
    rm -rf "$TARBALL" "$SPLIT_DIR"

    echo "[CACHE] AOSP source cached successfully!"
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