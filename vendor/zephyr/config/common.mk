# ============================================================================
# ZephyrOS — Common Vendor Configuration
# ----------------------------------------------------------------------------
# 全局共用的构建标识、包引入、属性开关。
# 被 products/zephyr_gsi.mk 包含，不直接 lunch。
# ============================================================================

# 清风品牌标识
PRODUCT_BRAND := ZephyrOS
PRODUCT_MANUFACTURER := zephyr
PRODUCT_NAME := zephyr

# 系统属性（build.prop）
PRODUCT_PROPERTY_OVERRIDES += \
    ro.zephyr.version=1.0 \
    ro.zephyr.releasetype=community \
    ro.zephyr.build.date=$(shell date -u +%Y%m%d) \
    ro.modversion=ZephyrOS-1.0

# ---------- 纯净系统承诺：禁用一切商业推广 / 远程广告组件 ----------

# ---------- 原创功能模块包 ----------
PRODUCT_PACKAGES += \
    ZephyrParts \
    ZephyrWallpapers \
    ZephyrSystemUIHooks \
    ZephyrSystemUIHooksApp

# ---------- 桌面启动器 ----------
# 替换 AOSP 默认 Launcher3 为 Lawnchair
$(call inherit-product, vendor/zephyr/launcher/zephyr_launcher.mk)

# ---------- 原创资源 ----------
# 开机动画 (ZephyrOS 原创设计)
$(call inherit-product-if-exists, vendor/zephyr/bootanimation/zephyr_bootanimation.mk)

# 原创字体集成 (基于 OFL 开源字体)
$(call inherit-product-if-exists, vendor/zephyr/fonts/zephyr_fonts.mk)

# 图标包 (PixelOS 风格, Apache 2.0)
$(call inherit-product-if-exists, vendor/zephyr/icons/zephyr_icons.mk)

# ---------- 默认关闭遥测 ----------
PRODUCT_PROPERTY_OVERRIDES += \
    persist.zephyr.telemetry=false

# ---------- 中文用户友好默认 ----------
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.timezone=Asia/Shanghai \
    ro.product.locale.language=zh \
    ro.product.locale.region=CN

# ---------- Overlay 引入 ----------
PRODUCT_PACKAGE_OVERLAYS += vendor/zephyr/overlay

# ---------- 许可证文件 ----------
PRODUCT_COPY_FILES += \
    vendor/zephyr/config/zephyr_copyright.txt:system/etc/zephyr_copyright.txt \
    vendor/zephyr/config/LICENSES.txt:system/etc/licenses/LICENSES.txt \
    vendor/zephyr/fonts/FONT_LICENSES.txt:system/etc/licenses/ZephyrFontLicenses.txt \
    vendor/zephyr/icons/ICON_LICENSES.txt:system/etc/licenses/ZephyrIconLicenses.txt \
    vendor/zephyr/launcher/LAWNCHAIR_LICENSES.txt:system/etc/licenses/ZephyrLawnchairLicenses.txt
