# ============================================================================
# ZephyrOS — Launcher Configuration
# ----------------------------------------------------------------------------
# 替换 AOSP 默认 Launcher3 为 Lawnchair.
#
# 策略:
#   1. 从 PRODUCT_PACKAGES 中移除 Launcher3 (Trebuchet / Launcher3QuickStep)
#   2. 添加 Lawnchair 到 PRODUCT_PACKAGES
#   3. 通过 overlay 修改 default launcher 配置
#   4. 设置 Lawnchair 为 HOME intent 默认处理器
# ============================================================================

# ---------- 移除 AOSP 默认 Launcher ----------
# 这些包名是 AOSP 14 中 Launcher3 的不同变体
PRODUCT_PACKAGES += \
    Lawnchair

# 替换 AOSP 默认 Launcher3 (在 GSI 中通常是 Launcher3QuickStep)
# 通过 overlay 覆盖 config_default_launcher 配置
PRODUCT_PACKAGE_OVERLAYS += vendor/zephyr/overlay/launcher

# 标识
PRODUCT_PROPERTY_OVERRIDES += \
    ro.zephyr.launcher=lawnchair

# ---------- 设置 Lawnchair 为默认 HOME ----------
# 通过 persistent preferred activity 配置, 让 Lawnchair 自动成为桌面
PRODUCT_COPY_FILES += \
    vendor/zephyr/launcher/default_launcher.xml:system/etc/default_launcher.xml
