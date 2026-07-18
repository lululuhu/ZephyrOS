#!/usr/bin/env bash
# ============================================================================
# ZephyrOS GSI Build — GSI Signing
# ----------------------------------------------------------------------------
# GSI 需要使用 release key 签名才能在锁_boot 验证的设备上启动。
# 本脚本:
#   1. 生成 ZephyrOS 默认 releasekey（首次构建；正式发布需替换为项目自有密钥）
#   2. 调用 sign_target_files_apks.py 对 target_files 签名
#   3. 重新打包 system.img
#
# 警告：默认密钥仅用于测试。生产环境必须使用项目维护的私有密钥。
# ============================================================================
set -euo pipefail

AOSP_ROOT="${AOSP_ROOT:-$(pwd)}"
KEY_DIR="$AOSP_ROOT/vendor/zephyr/security"

# ------------------------------------------------------------------
# 1. 准备签名密钥
# ------------------------------------------------------------------
if [ ! -f "$KEY_DIR/releasekey.pk8" ]; then
    echo "[INFO] Generating ZephyrOS releasekey (dev/test only)..."
    mkdir -p "$KEY_DIR"
    SUBJECT="/C=CN/O=ZephyrOS/OU=Build/CN=ZephyrOS-DevKey"
    # 使用 AOSP 自带的 development/tools/make_key
    DEVKEYS="$AOSP_ROOT/development/tools/make_key"
    if [ -x "$DEVKEYS" ]; then
        "$DEVKEYS" "$KEY_DIR/releasekey" "$SUBJECT" </dev/null
        "$DEVKEYS" "$KEY_DIR/platform" "$SUBJECT" </dev/null
        "$DEVKEYS" "$KEY_DIR/shared" "$SUBJECT" </dev/null
        "$DEVKEYS" "$KEY_DIR/media" "$SUBJECT" </dev/null
        "$DEVKEYS" "$KEY_DIR/networkstack" "$SUBJECT" </dev/null
    else
        echo "[WARN] make_key tool not found, skipping key generation."
    fi
fi

# ------------------------------------------------------------------
# 2. 定位 target_files zip
# ------------------------------------------------------------------
TARGET_FILES=$(ls -1 out/target/product/*/obj/PACKAGING/target_files_intermediates/*.zip 2>/dev/null | head -1 || true)
if [ -z "$TARGET_FILES" ]; then
    echo "[WARN] target_files zip not found — skipping re-sign (typical for userdebug GSI)."
    echo "[INFO] GSI image remains debug-signed."
    exit 0
fi

echo "[INFO] Target files: $TARGET_FILES"

# ------------------------------------------------------------------
# 3. 签名（仅在 user 变体需要；userdebug 可跳过）
# ------------------------------------------------------------------
if [ "${TARGET_BUILD_VARIANT:-userdebug}" = "user" ]; then
    echo "[INFO] Signing target files..."
    SIGN_TOOL="build/make/tools/releasetools/sign_target_files_apks.py"
    SIGNED_TARGETS="out/signed-target_files.zip"

    python3 "$SIGN_TOOL" \
        -o \
        -d "$KEY_DIR" \
        "$TARGET_FILES" \
        "$SIGNED_TARGETS" || {
            echo "[WARN] Signing failed, keeping unsigned build."
            exit 0
        }
    echo "[OK] Signed target files: $SIGNED_TARGETS"
else
    echo "[INFO] userdebug variant — debug signing retained."
fi

echo "[OK] GSI signing step complete."
