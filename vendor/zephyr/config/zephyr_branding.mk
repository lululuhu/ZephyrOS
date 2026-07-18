# ============================================================================
# ZephyrOS — Build Properties (build.prop branding)
# ----------------------------------------------------------------------------
# 全面替换 AOSP 默认品牌信息, 让系统处处显示 ZephyrOS.
# 这些属性会写入 /system/build.prop 与 /vendor/build.prop.
# ============================================================================

# ---------- 设备品牌标识 (在设置/启动器/关于手机中显示) ----------
PRODUCT_MANUFACTURER := ZephyrOS
PRODUCT_BRAND := ZephyrOS
PRODUCT_MODEL := ZephyrOS 1.0
PRODUCT_DEVICE := zephyr_gsi
PRODUCT_NAME := zephyr_gsi

# ---------- 内部属性 (build.prop) ----------
PRODUCT_PROPERTY_OVERRIDES += \
    ro.build.product=zephyr_gsi \
    ro.product.build.fingerprint=ZephyrOS/zephyr_gsi/zephyr:14/UQ1A.240101.001/zephyr01:userdebug/release-keys \
    ro.product.manufacturer=ZephyrOS \
    ro.product.brand=ZephyrOS \
    ro.product.model=ZephyrOS \
    ro.product.device=zephyr_gsi \
    ro.product.name=zephyr_gsi \
    ro.build.fingerprint=ZephyrOS/zephyr_gsi/zephyr:14/UQ1A.240101.001/zephyr01:userdebug/release-keys

# ---------- ZephyrOS 自有版本信息 ----------
PRODUCT_PROPERTY_OVERRIDES += \
    ro.zephyr.version=1.0 \
    ro.zephyr.version.display=ZephyrOS 1.0 \
    ro.zephyr.codename=Breeze \
    ro.zephyr.releasetype=community \
    ro.zephyr.build.date=$(shell date -u +%Y%m%d) \
    ro.modversion=ZephyrOS-1.0 \
    ro.lineage.build.version=ZephyrOS-1.0

# ---------- Android 版本号微调 (保持官方安全补丁) ----------
PRODUCT_PROPERTY_OVERRIDES += \
    ro.build.id=UQ1A.240101.001 \
    ro.build.version.incremental=ZephyrOS-1.0 \
    ro.build.display.id=ZephyrOS-1.0

# ---------- 默认主题标识 ----------
PRODUCT_PROPERTY_OVERRIDES += \
    ro.zephyr.theme=Breeze \
    ro.zephyr.accent=green \
    ro.zephyr.font=default

# ---------- 用户体验相关 ----------
# 关闭 AOSP 调试信息显示
PRODUCT_PROPERTY_OVERRIDES += \
    ro.adb.secure=1 \
    ro.debuggable=0

# ---------- PixelOS 风格定位 ----------
# 让部分应用误判为 Pixel 设备以启用 Pixel 专属 UI
PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.vendor.manufacturer=Google \
    ro.product.vendor.model=Pixel 8 \
    ro.product.system.manufacturer=ZephyrOS \
    ro.product.system.model=ZephyrOS 1.0
