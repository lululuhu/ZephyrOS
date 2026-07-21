#!/usr/bin/env bash
# ============================================================================
# ZephyrOS GSI Build — Main Build Script
# ----------------------------------------------------------------------------
# 前置条件:
#   - 当前工作目录为 AOSP 根
#   - ZephyrOS overlay 已铺到 vendor/zephyr / packages/apps/ZephyrParts
#
# 本脚本会自行 source build/envsetup.sh + lunch, 因为 m 是 shell 函数,
# 无法跨进程传递 (CI 中 bash 调用脚本会启动新 shell, 函数丢失).
#
# 目标产物: out/target/product/<device>/system.img
# ============================================================================
set -euo pipefail

# ------------------------------------------------------------------
# 0. 重新初始化 AOSP 构建环境 (m/soong_ui 等是 shell 函数, 不跨进程)
# ------------------------------------------------------------------
BUILD_TARGET_LUNCH="${TARGET_LUNCH:-aosp_arm64-userdebug}"

if ! command -v m >/dev/null 2>&1; then
    echo "[INFO] Sourcing build/envsetup.sh + lunch (m function not available)..."
    # AOSP 的 envsetup.sh 引用了未定义的 TOP 变量, 在 bash -e 下会报错.
    # 显式设置 TOP 为当前目录 (AOSP 根) 再 source.
    export TOP=$(pwd)
    set +u
    source build/envsetup.sh
    lunch "$BUILD_TARGET_LUNCH"
    set -u
fi

# 启用 ccache（若环境变量已设置）
if [ "${USE_CCACHE:-1}" = "1" ]; then
    export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
    export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-5G}"
    mkdir -p "$CCACHE_DIR"
    prebuilt_build-tools/path/linux-x86/ccache -M "$CCACHE_MAXSIZE" 2>/dev/null || \
        ccache -M "$CCACHE_MAXSIZE" 2>/dev/null || true
    echo "[INFO] ccache enabled: dir=$CCACHE_DIR max=$CCACHE_MAXSIZE"
fi

# 后台磁盘监控（每 5 分钟输出一次）
# workspace 在 / 上, 不在 /mnt (runner 对 /mnt 无写权限)
(
    while true; do
        echo "[MONITOR] $(date +%H:%M:%S) disk: $(df -h / 2>/dev/null | tail -1 | awk '{print $4" free / "$5" used"}')"
        sleep 300
    done
) &
DISK_MONITOR_PID=$!
trap "kill $DISK_MONITOR_PID 2>/dev/null || true" EXIT

echo "::group::ZephyrOS Build Configuration"
echo "TARGET_PRODUCT   = ${TARGET_PRODUCT:-unknown}"
echo "TARGET_BUILD_TYPE= ${TARGET_BUILD_TYPE:-unknown}"
echo "TARGET_DEVICE    = ${TARGET_DEVICE:-unknown}"
echo "ZEPHYR_BUILD     = ${ZEPHYR_BUILD:-0}"
echo "Java version:"
java -version 2>&1 | head -1 || true
echo "::endgroup::"

# ------------------------------------------------------------------
# 构建核心目标
#   - systemimage  : 生成 system.img（GSI 核心）
#
# 注意: ZephyrParts / ZephyrWallpapers / ZephyrSystemUIHooks 等自定义模块
# 暂不加入构建目标。它们依赖 SystemUI 内部 API, 需要先确保基础 GSI 能
# 编译通过。后续通过 PRODUCT_PACKAGES 在 product mk 中启用。
# ------------------------------------------------------------------
BUILD_TARGETS=(
    "systemimage"
)

echo "[INFO] Starting build: ${BUILD_TARGETS[*]}"
START_TS=$(date +%s)

# 使用 m 命令（自动处理依赖与并行度），限制并行度避免 OOM
# GitHub Actions runner 只有 4 核 15GB RAM, 降到 -j1 避免 OOM
# 之前 -j2 导致构建被取消 (可能是 OOM 或磁盘不足)
BUILD_JOBS="${BUILD_JOBS:-1}"
m -j"$BUILD_JOBS" "${BUILD_TARGETS[@]}"

END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))
echo "[OK] Build finished in $((DURATION / 60))m $((DURATION % 60))s"

# ------------------------------------------------------------------
# 校验产物
# ------------------------------------------------------------------
SYSTEM_IMG=$(ls -1 out/target/product/*/system.img 2>/dev/null | head -1 || true)
if [ -z "$SYSTEM_IMG" ]; then
    echo "[ERROR] system.img not found!"
    exit 1
fi

echo "::group::Build Output"
ls -lh "$SYSTEM_IMG"
echo "Image path: $SYSTEM_IMG"
echo "::endgroup::"

echo "[OK] GSI system image built successfully."
