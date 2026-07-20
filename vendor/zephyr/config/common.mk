# ============================================================================
# ZephyrOS — Common Vendor Configuration
# ----------------------------------------------------------------------------
# 全局共用的构建标识、包引入、属性开关、品牌信息、PixelOS 风格 overlay.
# ============================================================================

# ---------- 清风品牌 + Pixel 设备伪装 (build.prop) ----------
$(call inherit-product, vendor/zephyr/config/zephyr_branding.mk)

# ---------- 原创功能模块包 ----------
# 注意: ZephyrWallpapers / ZephyrSystemUIHooks / ZephyrSystemUIHooksApp
# 暂未实现源码, 先移除避免编译错误。后续在 ZephyrParts 中统一实现。
PRODUCT_PACKAGES += \
    ZephyrParts

# ---------- 原创资源 ----------
$(call inherit-product-if-exists, vendor/zephyr/bootanimation/zephyr_bootanimation.mk)
$(call inherit-product-if-exists, vendor/zephyr/fonts/zephyr_fonts.mk)
$(call inherit-product-if-exists, vendor/zephyr/icons/zephyr_icons.mk)

# ---------- GSI 构建时不启用 Lawnchair (源码未同步) ----------
# 后续通过预编译 APK 集成
# $(call inherit-product, vendor/zephyr/launcher/zephyr_launcher.mk)

# ---------- PixelOS 风格 Overlay (核心改造, 让系统告别 AOSP 毛坯) ----------
# 1. Framework 配置 overlay (默认时区, 风格开关等)
# 2. SystemUI 主题 overlay (PixelOS 配色 + 圆角)
# 3. Settings 应用 overlay (ZephyrOS 品牌 + 关于手机定制)
# 4. 各 AOSP 应用 overlay (Dialer/Messaging/Contacts/Calendar/Calculator/DeskClock)
# 注意: 各应用 overlay 使用 inherit-product-if-exists, 避免因 AOSP 版本
# 差异导致 "no rule to make target" 错误
PRODUCT_PACKAGE_OVERLAYS += \
    vendor/zephyr/overlay

# ---------- 默认关闭遥测 ----------
PRODUCT_PROPERTY_OVERRIDES += \
    persist.zephyr.telemetry=false

# ---------- 中文用户友好默认 ----------
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.timezone=Asia/Shanghai \
    ro.product.locale.language=zh \
    ro.product.locale.region=CN

# ---------- 启用 Material You 主题 (PixelOS 风格核心) ----------
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.theme_enable=true \
    persist.sys.material_you=true

# ---------- 默认主题色 (清风绿) ----------
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.theme_accent_color=0xFF2EB872

# ---------- 许可证文件 ----------
PRODUCT_COPY_FILES += \
    vendor/zephyr/config/zephyr_copyright.txt:system/etc/zephyr_copyright.txt \
    vendor/zephyr/config/LICENSES.txt:system/etc/licenses/LICENSES.txt \
    vendor/zephyr/fonts/FONT_LICENSES.txt:system/etc/licenses/ZephyrFontLicenses.txt \
    vendor/zephyr/icons/ICON_LICENSES.txt:system/etc/licenses/ZephyrIconLicenses.txt \
    vendor/zephyr/launcher/LAWNCHAIR_LICENSES.txt:system/etc/licenses/ZephyrLawnchairLicenses.txt
