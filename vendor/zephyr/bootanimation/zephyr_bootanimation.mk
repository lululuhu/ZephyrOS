# ============================================================================
# ZephyrOS — Original Boot Animation Build Config
# ----------------------------------------------------------------------------
# 将 bootanimation.zip 安装到 /system/media/
# 生成在构建前由 Soong 自定义 Python 触发, 或在 CI 中预生成.
# ============================================================================

# 拷贝 bootanimation.zip 到 system 分区
# 该文件由 vendor/zephyr/bootanimation/generate_bootanimation.py 生成
PRODUCT_COPY_FILES += \
    vendor/zephyr/bootanimation/bootanimation.zip:system/media/bootanimation.zip

# 关闭 AOSP 默认开机动画 (使用我们的)
PRODUCT_PROPERTY_OVERRIDES += \
    debug.sf.nobootanimation=0 \
    ro.bootanim.original=true
