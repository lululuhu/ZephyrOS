#!/usr/bin/env bash
# ============================================================================
# ZephyrOS GSI Build — Main Build Script
# ----------------------------------------------------------------------------
# 前置条件:
#   - 当前工作目录为 AOSP 根
#   - 已执行 source build/envsetup.sh && lunch <target>
#   - ZephyrOS overlay 已铺到 vendor/zephyr / packages/apps/ZephyrParts
#
# 本脚本构建 GSI system image，并在构建过程中实时监控磁盘。
# 目标产物: out/target/product/<device>/system.img
# ============================================================================
set -euo pipefail

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
#   - ZephyrParts  : 自定义设置应用
# ------------------------------------------------------------------
BUILD_TARGETS=(
    "systemimage"
    "ZephyrParts"
)

echo "[INFO] Starting build: ${BUILD_TARGETS[*]}"
START_TS=$(date +%s)

# 使用 m 命令（自动处理依赖与并行度），限制并行度避免 OOM
# AOSP 14 推荐使用 m 而非 make
m -j"$(nproc)" "${BUILD_TARGETS[@]}"

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
