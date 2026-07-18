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
# 1. 安装 repo 工具（清华大学镜像，国内访问更快）
# ------------------------------------------------------------------
if ! command -v repo >/dev/null 2>&1; then
    echo "[INFO] Installing repo tool (from TUNA mirror)..."
    curl -sSL https://mirrors.tuna.tsinghua.edu.cn/git/git-repo \
        -o /tmp/repo
    chmod +x /tmp/repo
    sudo mv /tmp/repo /usr/local/bin/repo
fi
repo version

# ------------------------------------------------------------------
# 2. 初始化 AOSP 仓库（使用清华大学镜像 + 浅克隆，节省 ~60% 磁盘）
#    清华镜像官方文档: https://mirrors.tuna.tsinghua.edu.cn/help/AOSP/
#    正确 URL: https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/platform/manifest
# ------------------------------------------------------------------
TUNA_MANIFEST_URL="https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/platform/manifest"

if [ ! -d ".repo" ]; then
    echo "[INFO] Initializing AOSP repo from TUNA mirror (shallow, depth=1)..."
    repo init -u "$TUNA_MANIFEST_URL" \
        -b "$ANDROID_TAG" \
        --depth=1 \
        --current-branch
else
    echo "[INFO] .repo already exists, skipping init."
fi

# ------------------------------------------------------------------
# 2.1 配置 git 使用清华镜像作为 AOSP 源 url 替换
#     这样 manifest 中引用的 android.googlesource.com 也会走清华镜像
# ------------------------------------------------------------------
git config --global url."https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/".insteadOf \
    "https://android.googlesource.com/"
echo "[INFO] Configured git url.insteadOf for TUNA AOSP mirror."

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
#    清华 TUNA 官方建议: 并发数不宜太高, 否则会出现 503 错误
#    文档明确推荐 -j4, 这里强制使用 -j4 以保证稳定同步
#    --no-tags 节省空间; --no-clone-bundle 避免 CDN 缓存命中失败
#    -c 仅同步当前分支; -f 容忍部分非关键项目失败
# ------------------------------------------------------------------
JOBS=4
echo "[INFO] Syncing AOSP source with -j$JOBS (TUNA recommended to avoid 503)..."
echo "[INFO] Estimated source size: ~28 GB (shallow)"

repo sync -c -j"$JOBS" \
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
