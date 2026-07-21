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

# 启用命令追踪 (便于诊断 runner 崩溃原因), 同时写入日志文件
exec > >(tee -a /tmp/setup_env.log) 2>&1
set -x

ANDROID_TAG="${1:-android-13.0.0_r83}"
AOSP_ROOT="${2:-/mnt/aosp}"
ZEPHYR_MANIFEST="${3:-}"
# remove-projects.xml 与 zephyr.xml 位于同一目录
ZEPHYR_MANIFEST_DIR="$(dirname "$ZEPHYR_MANIFEST" 2>/dev/null || echo "")"

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
    # Google 源: 降到 -j1, 逐项目同步。
    # -j2/-j4 下 runner 多次在 13-33 分钟崩溃 (无日志, BlobNotFound)。
    # -j1 最大限度降低内存/磁盘峰值, 虽然 慢但能完成。
    SYNC_JOBS=1
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
    echo "[INFO] Initializing AOSP repo from $AOSP_MIRROR (shallow clone)..."
    # --depth=1: 浅克隆, 只取最新 commit (省 ~60% 磁盘)
    # 注意: 曾尝试 --partial-clone (blob:none), sync 成功且省磁盘, 但
    #   导致 lunch 时 release_config.mk 报错 (build/release/ 下某些文件
    #   在 partial clone 下未下载, make 读取失败)。AOSP 构建系统不兼容
    #   partial clone, 故改回普通浅克隆。
    # -g default: 显式指定 default group (虽然 -g default 是空操作, 但保留
    #   语义清晰; 真正的瘦身靠 remove-projects.xml)
    repo init -u "$MANIFEST_URL" \
        -b "$ANDROID_TAG" \
        -g default \
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
#    remove-projects.xml 已清空 (AOSP 13 项目差异过大, 改用 post-sync cleanup)
# ------------------------------------------------------------------
LOCAL_MANIFEST_DIR=".repo/local_manifests"
mkdir -p "$LOCAL_MANIFEST_DIR"
if [ -n "$ZEPHYR_MANIFEST" ] && [ -f "$ZEPHYR_MANIFEST" ]; then
    cp -f "$ZEPHYR_MANIFEST" "$LOCAL_MANIFEST_DIR/zephyr.xml"
    echo "[INFO] ZephyrOS local manifest applied: $ZEPHYR_MANIFEST"
fi
# 应用项目移除清单 (移除 cts/pdk/androidx/studio 等不需要的大型项目)
REMOVE_MANIFEST="$ZEPHYR_MANIFEST_DIR/remove-projects.xml"
if [ -n "$ZEPHYR_MANIFEST_DIR" ] && [ -f "$REMOVE_MANIFEST" ]; then
    cp -f "$REMOVE_MANIFEST" "$LOCAL_MANIFEST_DIR/remove-projects.xml"
    echo "[INFO] AOSP source slimming manifest applied: $REMOVE_MANIFEST"
    echo "[INFO]   (removes cts, pdk, androidx, maven_repo, tools/studio, etc.)"
fi

# ------------------------------------------------------------------
# 4. 同步源码
#    并发数根据镜像选择:
#      - tuna (清华): 官方建议 -j4 避免触发 503
#      - google: 降到 -j2, 避免 GitHub runner I/O/内存峰值崩溃
#    group 过滤在 repo init 阶段已通过 -g default 完成 (repo sync
#      本身不支持 -g 选项)
#    --no-tags 节省空间; --no-clone-bundle 避免 CDN 缓存命中失败
#    -c 仅同步当前分支; -f 容忍部分非关键项目失败
# ------------------------------------------------------------------
echo "[INFO] Syncing AOSP source with -j$SYNC_JOBS ($AOSP_MIRROR mirror)..."
echo "[INFO] Estimated source size: ~28 GB (shallow)"

# sync 前打印磁盘/内存状态 (用于诊断 runner 崩溃)
echo "::group::Resource status before sync"
df -h "$AOSP_ROOT"
free -h
echo "::endgroup::"

# 后台磁盘/内存监控 (每 60s 输出一次, 便于诊断 OOM/disk full)
(
    while true; do
        echo "[MONITOR] $(date -u +%H:%M:%S) disk=$(df -h "$AOSP_ROOT" | tail -1 | awk '{print $4" free / "$5" used"}') mem=$(free -h | awk '/^Mem:/{print $7" avail"}')"
        sleep 60
    done
) &
MONITOR_PID=$!
trap "kill $MONITOR_PID 2>/dev/null || true" EXIT

if ! repo sync -c -j"$SYNC_JOBS" \
        --no-tags \
        --no-clone-bundle \
        --prune \
        --optimized-fetch \
        -f; then
    kill $MONITOR_PID 2>/dev/null || true
    trap - EXIT
    echo "[ERROR] repo sync failed. AOSP source not available, cannot continue."
    echo "[INFO] Disk status after failed sync:"
    df -h "$AOSP_ROOT"
    exit 1
fi

kill $MONITOR_PID 2>/dev/null || true
trap - EXIT

# ------------------------------------------------------------------
# 4.1 清理 .repo 元数据 (释放 5-10GB 磁盘给构建用)
#     repo sync 完成后, .repo/projects 和 .repo/project-objects 中的
#     git 元数据不再需要 (CI 一次性构建, 不需要再次 sync)。
#     保留 .repo/manifest*.xml (构建脚本读取版本信息用)
# ------------------------------------------------------------------
echo "[INFO] Cleaning .repo git metadata to free disk for build..."
REPO_META_SIZE=$(du -sh .repo 2>/dev/null | awk '{print $1}' || echo "unknown")
echo "[INFO] .repo size before cleanup: $REPO_META_SIZE"
rm -rf .repo/projects .repo/project-objects 2>/dev/null || true
# 保留 .repo/manifests 目录 (包含 manifest 定义) 和 .repo/manifest.xml
echo "[INFO] .repo metadata cleanup done."
df -h "$AOSP_ROOT"

# ------------------------------------------------------------------
# 5. 同步后清理大型目录 (释放磁盘空间给构建)
#    这些设备树和内核预编译文件在 GSI 构建中不需要,
#    但无法通过 remove-project 安全移除 (AOSP 版本间差异大),
#    所以同步完成后直接删除。
# ------------------------------------------------------------------
echo "[INFO] Post-sync cleanup: removing device trees and kernel prebuilts..."
# Pixel 设备树 (GSI 不需要)
rm -rf "$AOSP_ROOT/device/google/akita"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/barbet"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/bluejay"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/bramble"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/caimito"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/comet"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/contexthub" 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/coral"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/cuttlefish"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/felix"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/gs101"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/gs201"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/lynx"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/pantah"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/raviole"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/redbull"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/redfin"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/shusky"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/sunfish"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/tangorpro"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/zuma"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/zumapro"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/atv" 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/google/trout" 2>/dev/null || true
# 其他厂商设备树
rm -rf "$AOSP_ROOT/device/amlogic" 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/linaro" 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/generic/mini-emulator"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/generic/vulkan-cereal" 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/generic/opengl-transport" 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/generic/goldfish"* 2>/dev/null || true
rm -rf "$AOSP_ROOT/device/generic/x86"* 2>/dev/null || true
# 内核预编译 (GSI 不需要)
rm -rf "$AOSP_ROOT/kernel/prebuilts" 2>/dev/null || true
# Trusty TEE (设备专用, GSI 不需要)
rm -rf "$AOSP_ROOT/trusty" 2>/dev/null || true
echo "[OK] Post-sync cleanup done."

# ------------------------------------------------------------------
# 6. 显示同步后磁盘占用
# ------------------------------------------------------------------
echo "::group::Disk usage after sync"
df -h "$AOSP_ROOT"
du -sh "$AOSP_ROOT" 2>/dev/null || true
echo "::endgroup::"

# ------------------------------------------------------------------
# 7. 注入 ZephyrOS 构建标识
# ------------------------------------------------------------------
cat > "$AOSP_ROOT/.zephyr_build_env" <<EOF
ZEPHYR_BUILD=1
ZEPHYR_ANDROID_TAG=$ANDROID_TAG
ZEPHYR_BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "[OK] Environment setup complete."
