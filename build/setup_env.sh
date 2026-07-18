#!/usr/bin/env bash
# ============================================================================
# ZephyrOS GSI Build — Environment Setup
# ----------------------------------------------------------------------------
# 用法:
#   setup_env.sh <android_tag> <aosp_root>
#
# 作用:
#   1. 安装 Google repo 工具
#   2. 在 <aosp_root> 浅克隆指定 Android tag 的 AOSP 源码
#   3. 跳过 GSI 构建无关的子项目以节省磁盘与时间
#   4. 打印最终磁盘占用
# ============================================================================
set -euo pipefail

ANDROID_TAG="${1:-android-14.0.0_r74}"
AOSP_ROOT="${2:-/mnt/aosp}"
ZEPHYR_MANIFEST="${3:-}"

echo "[INFO] Android tag : $ANDROID_TAG"
echo "[INFO] AOSP root   : $AOSP_ROOT"
echo "[INFO] Zephyr manifest: $ZEPHYR_MANIFEST"

mkdir -p "$AOSP_ROOT"
cd "$AOSP_ROOT"

# ------------------------------------------------------------------
# 1. 选择 AOSP 源镜像
#    - GitHub Actions (CI=true) runner 通常在美国, 用 Google 官方源最快
#    - 本地构建(国内) 用清华 TUNA 镜像, 避免墙的问题
#    也可通过环境变量 AOSP_MIRROR=google|tuna 强制指定
# ------------------------------------------------------------------
AOSP_MIRROR="${AOSP_MIRROR:-}"
if [ -z "$AOSP_MIRROR" ]; then
    if [ "${CI:-false}" = "true" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
        AOSP_MIRROR="google"
    else
        AOSP_MIRROR="tuna"
    fi
fi
echo "[INFO] AOSP mirror selection: $AOSP_MIRROR"

if [ "$AOSP_MIRROR" = "tuna" ]; then
    MANIFEST_URL="https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/platform/manifest"
    REPO_URL="https://mirrors.tuna.tsinghua.edu.cn/git/git-repo"
    SYNC_JOBS=4   # 清华官方建议: -j4 避免触发 503
else
    MANIFEST_URL="https://android.googlesource.com/platform/manifest"
    REPO_URL="https://storage.googleapis.com/git-repo-downloads/repo"
    SYNC_JOBS=$(nproc)  # Google 源无并发限制, 用满 CPU
fi

# ------------------------------------------------------------------
# 1.1 安装 repo 工具
# ------------------------------------------------------------------
if ! command -v repo >/dev/null 2>&1; then
    echo "[INFO] Installing repo tool (from $AOSP_MIRROR)..."
    curl -sSL "$REPO_URL" -o /tmp/repo
    chmod +x /tmp/repo
    sudo mv /tmp/repo /usr/local/bin/repo
fi
repo version

# ------------------------------------------------------------------
# 2. 初始化 AOSP 仓库（浅克隆，节省 ~60% 磁盘）
# ------------------------------------------------------------------
if [ ! -d ".repo" ]; then
    echo "[INFO] Initializing AOSP repo from $AOSP_MIRROR (shallow, depth=1)..."
    repo init -u "$MANIFEST_URL" \
        -b "$ANDROID_TAG" \
        --depth=1 \
        --current-branch
else
    echo "[INFO] .repo already exists, skipping init."
fi

# ------------------------------------------------------------------
# 2.1 配置 git url 替换 (仅清华镜像需要, 让 manifest 中
#      android.googlesource.com 的引用也走清华)
# ------------------------------------------------------------------
if [ "$AOSP_MIRROR" = "tuna" ]; then
    git config --global url."https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/".insteadOf \
        "https://android.googlesource.com/"
    echo "[INFO] Configured git url.insteadOf for TUNA AOSP mirror."
fi

# ------------------------------------------------------------------
# 3. 应用 ZephyrOS local manifest（在 sync 前完成, 以便拉取 Lawnchair 等）
# ------------------------------------------------------------------
LOCAL_MANIFEST_DIR=".repo/local_manifests"
mkdir -p "$LOCAL_MANIFEST_DIR"
if [ -n "$ZEPHYR_MANIFEST" ] && [ -f "$ZEPHYR_MANIFEST" ]; then
    cp -f "$ZEPHYR_MANIFEST" "$LOCAL_MANIFEST_DIR/zephyr.xml"
    echo "[INFO] ZephyrOS local manifest applied: $ZEPHYR_MANIFEST"
fi

# ------------------------------------------------------------------
# 4. 同步源码
#    并发数根据镜像选择:
#      - tuna (清华): 官方建议 -j4 避免触发 503
#      - google: 无并发限制, 用满 CPU
#    --no-tags 节省空间; --no-clone-bundle 避免 CDN 缓存命中失败
#    -c 仅同步当前分支; -f 容忍部分非关键项目失败
# ------------------------------------------------------------------
echo "[INFO] Syncing AOSP source with -j$SYNC_JOBS ($AOSP_MIRROR mirror)..."
echo "[INFO] Estimated source size: ~28 GB (shallow)"

repo sync -c -j"$SYNC_JOBS" \
    --no-tags \
    --no-clone-bundle \
    --prune \
    --force-sync \
    -f

# ------------------------------------------------------------------
# 5. 显示同步后磁盘占用
# ------------------------------------------------------------------
echo "::group::Disk usage after sync"
df -h "$AOSP_ROOT"
du -sh "$AOSP_ROOT" 2>/dev/null || true
echo "::endgroup::"

# ------------------------------------------------------------------
# 6. 注入 ZephyrOS 构建标识
# ------------------------------------------------------------------
cat > "$AOSP_ROOT/.zephyr_build_env" <<EOF
ZEPHYR_BUILD=1
ZEPHYR_ANDROID_TAG=$ANDROID_TAG
ZEPHYR_BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "[OK] Environment setup complete."
