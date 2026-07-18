# ============================================================================
# ZephyrOS — GSI (Generic System Image) Product
# ----------------------------------------------------------------------------
# lunch 目标: zephyr_gsi-userdebug / zephyr_gsi-user
# 适用: 任何支持 Project Treble 的设备（通过 fastboot flash system 刷入）
# ============================================================================

# 继承 GSI 基线（AOSP 14 自带）
$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_system.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

# ZephyrOS 自有配置
$(call inherit-product, vendor/zephyr/config/common.mk)

# ---------- GSI 必备约束 ----------
# GSI 必须无 vendor 分区依赖，因此不能引入厂商 blob
PRODUCT_ENFORCE_VINTF_MANIFEST := true
PRODUCT_SHIPPING_API_LEVEL := 34

# ---------- 设备通用名 ----------
PRODUCT_NAME := zephyr_gsi
PRODUCT_DEVICE := generic
PRODUCT_MODEL := ZephyrOS GSI

# ---------- GSI 必须支持的所有 ABIs ----------
PRODUCT_ABIS := arm64-v8a

# ---------- 解锁 treble 兼容 ----------
PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE := true

# ---------- SystemUI overlay 注入 ----------
PRODUCT_PACKAGE_OVERLAYS += vendor/zephyr/overlay
