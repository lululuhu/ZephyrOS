# ============================================================================
# ZephyrOS — Original Fonts Configuration
# ----------------------------------------------------------------------------
# 字体策略:
#   - 不使用 AOSP 默认 Roboto 单一字体
#   - 集成 OFL (SIL Open Font License) 开源字体, 商用自由
#   - 提供 3 种字体风格供用户在 ThemeStudio 切换:
#       1. 清风默认 (Roboto + Noto Sans CJK 调校)
#       2. 清风黑体 (基于思源黑体 Heavy 衍生权重)
#       3. 清风圆体 (基于 Varela Round 圆体衍生)
#
# 字体文件获取:
#   cd vendor/zephyr/fonts
#   bash download_fonts.sh
#
# OFL 字体来源 (合法, 可商用):
#   - Roboto:      https://fonts.google.com/specimen/Roboto
#   - Noto Sans CJK: https://github.com/notofonts/noto-cjk
#   - Varela Round: https://fonts.google.com/specimen/Varela+Round
# ============================================================================

# 安装清风字体配置
PRODUCT_COPY_FILES += \
    vendor/zephyr/fonts/fonts.xml:system/etc/fonts.xml

# 安装字体文件本体 (由 download_fonts.sh 下载)
PRODUCT_COPY_FILES += \
    vendor/zephyr/fonts/files/ZephyrSans-Regular.ttf:system/fonts/ZephyrSans-Regular.ttf \
    vendor/zephyr/fonts/files/ZephyrSans-Medium.ttf:system/fonts/ZephyrSans-Medium.ttf \
    vendor/zephyr/fonts/files/ZephyrSans-Bold.ttf:system/fonts/ZephyrSans-Bold.ttf \
    vendor/zephyr/fonts/files/ZephyrRound-Regular.ttf:system/fonts/ZephyrRound-Regular.ttf \
    vendor/zephyr/fonts/files/ZephyrCJK-Regular.otf:system/fonts/ZephyrCJK-Regular.otf \
    vendor/zephyr/fonts/files/ZephyrCJK-Bold.otf:system/fonts/ZephyrCJK-Bold.otf

# 清风字体属性标识
PRODUCT_PROPERTY_OVERRIDES += \
    ro.zephyr.fonts.default=ZephyrSans
