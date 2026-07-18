# ============================================================================
# ZephyrOS — Icon Pack
# ----------------------------------------------------------------------------
# 图标来源: PixelOS (https://github.com/PixelOS-AOSP)
# 许可证:   Apache License 2.0 (与 AOSP 兼容)
#
# 本目录为 ZephyrOS 对 PixelOS 图标的适配层:
#   1. 通过 manifest/zephyr.xml 把 PixelOS 图标仓库 clone 到
#      vendor/zephyr/icons/pixelos/
#   2. 本 overlay 把 PixelOS 图标定向到 SystemUI / Launcher3 的资源覆盖路径
#   3. 不修改 PixelOS 原始资源文件, 仅做引用映射
#
# 启用步骤:
#   1. 在 manifest/zephyr.xml 中取消注释 PixelOS 图标 project
#   2. 在 vendor/zephyr/config/common.mk 中引入本 mk
# ============================================================================

# 仅在 PixelOS 图标仓库存在时启用 (通过 wildcard 检测)
ifneq ($(wildcard vendor/zephyr/icons/pixelos/),)

# PixelOS 图标作为 SystemUI overlay
PRODUCT_PACKAGE_OVERLAYS += vendor/zephyr/icons/pixelos/overlay

# 标识
PRODUCT_PROPERTY_OVERRIDES += \
    ro.zephyr.iconpack=pixelos

endif
