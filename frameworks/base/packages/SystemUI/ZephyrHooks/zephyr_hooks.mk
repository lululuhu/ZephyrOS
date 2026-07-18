# ============================================================================
# ZephyrOS SystemUI Hooks — Build Config
# ----------------------------------------------------------------------------
# 将 ZephyrStatusBarController / ZephyrGestureController 编入 SystemUI.
# ============================================================================

PRODUCT_PACKAGES += \
    ZephyrSystemUIHooks \
    ZephyrSystemUIHooksApp

# 标识 ZephyrOS SystemUI 钩子已启用
PRODUCT_PROPERTY_OVERRIDES += \
    ro.zephyr.systemui_hooks=1
