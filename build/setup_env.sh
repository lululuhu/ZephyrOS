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
#    清华镜像地址: https://aosp.tuna.tsinghua.edu.cn/platform/manifest
# ------------------------------------------------------------------
TUNA_MANIFEST_URL="https://aosp.tuna.tsinghua.edu.cn/platform/manifest"

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
# ------------------------------------------------------------------
# repo 工具会通过 .repo/manifests.xml 中的 url 拉取每个子项目,
# 清华镜像需要在 .repo/manifests.git/config 中重写 url,
# 或者通过 git config --global url.<替代>.insteadOf 实现。
git config --global url."https://aosp.tuna.tsinghua.edu.cn/".insteadOf \
    "https://android.googlesource.com/"
git config --global url."https://mirrors.tuna.tsinghua.edu.cn/git/android.googlesource.com/".insteadOf \
    "android.googlesource.com:"
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
#    使用 -j 取决于 CPU 数；--no-tags 节省空间；--no-clone-bundle 避免 CDN
#    缓存命中失败。-c 仅同步当前分支。
# ------------------------------------------------------------------
JOBS=$(nproc)
echo "[INFO] Syncing AOSP source with -j$JOBS..."
echo "[INFO] Estimated source size: ~28 GB (shallow)"

# 同步核心项目；跳过大量设备树（GSI 不需要）
# 通过 -f 容忍部分非关键项目失败
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
