#!/usr/bin/env bash
# ============================================================================
# ZephyrOS — Local Build One-Click Script (for WSL2 / Ubuntu)
# ----------------------------------------------------------------------------
# 适用: 64 位 Linux + 64GB 空闲磁盘 + 16GB RAM
# 不需要懂编译, 双击运行即可.
#
# 用法:
#   bash build_local.sh
#
# 完成后产出: out/target/product/generic/system.img
# ============================================================================
set -e

# ============ 配置 ============
ANDROID_TAG="android-14.0.0_r74"
TARGET="zephyr_gsi-userdebug"
AOSP_DIR="$HOME/zephyr-aosp"
# ==============================

echo "=========================================="
echo "  ZephyrOS — Local GSI Build"
echo "=========================================="
echo ""
echo "Android : $ANDROID_TAG"
echo "Target  : $TARGET"
echo "Dir     : $AOSP_DIR"
echo ""

# 1. 检查环境
echo "[1/8] Checking environment..."
[ "$(uname -m)" = "x86_64" ] || { echo "[ERROR] 需要 x86_64 架构"; exit 1; }
FREE_GB=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | sed 's/G//')
[ "$FREE_GB" -ge 60 ] || { echo "[ERROR] 需要至少 60GB 空闲磁盘, 当前 ${FREE_GB}GB"; exit 1; }
echo "[OK] $(nproc) cores, ${FREE_GB}GB free disk"

# 2. 安装依赖
echo ""
echo "[2/8] Installing dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    git-core gnupg flex bison gperf build-essential \
    zip curl zlib1g-dev gcc-multilib g++-multilib \
    libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev \
    libx11-dev lib32z-dev ccache libgl1-mesa-dev \
    libxml2-utils xsltproc unzip python3 python3-pip \
    repo rsync

# 3. 安装 repo
echo ""
echo "[3/8] Installing repo tool..."
if ! command -v repo >/dev/null 2>&1; then
    curl -sSL https://storage.googleapis.com/git-repo-downloads/repo -o /tmp/repo
    chmod +x /tmp/repo
    sudo mv /tmp/repo /usr/local/bin/repo
fi

# 4. 配置 git
echo ""
echo "[4/8] Configuring git..."
git config --global user.name "ZephyrOS Builder" 2>/dev/null || true
git config --global user.email "builder@zephyros.local" 2>/dev/null || true

# 5. 初始化 AOSP
echo ""
echo "[5/8] Initializing AOSP (this will take a while)..."
mkdir -p "$AOSP_DIR"
cd "$AOSP_DIR"

if [ ! -d ".repo" ]; then
    repo init -u https://android.googlesource.com/platform/manifest \
        -b "$ANDROID_TAG" --depth=1 --current-branch

    # 应用 ZephyrOS manifest
    mkdir -p .repo/local_manifests
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    cp "$SCRIPT_DIR/manifest/zephyr.xml" .repo/local_manifests/zephyr.xml

    echo ""
    echo "[INFO] Syncing AOSP source (~28GB, will take 30-60 min depending on network)..."
    repo sync -c -j$(nproc) --no-tags --no-clone-bundle --prune -f
fi

# 6. 应用 ZephyrOS overlay
echo ""
echo "[6/8] Applying ZephyrOS overlay..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
rsync -a --exclude='.git' --exclude='Lawnchair' \
    "$SCRIPT_DIR/packages/apps/" "$AOSP_DIR/packages/apps/"
rsync -a --exclude='.git' "$SCRIPT_DIR/vendor/zephyr/" "$AOSP_DIR/vendor/zephyr/"
rsync -a --exclude='.git' "$SCRIPT_DIR/frameworks/" "$AOSP_DIR/frameworks/" 2>/dev/null || true

# 7. 生成开机动画 + 下载字体 + 应用补丁
echo ""
echo "[7/8] Generating resources..."
pip install Pillow --quiet 2>/dev/null || true
(cd "$AOSP_DIR/vendor/zephyr/bootanimation" && python3 generate_bootanimation.py) || \
    echo "[WARN] Boot animation generation failed"
bash "$AOSP_DIR/vendor/zephyr/fonts/download_fonts.sh" || \
    echo "[WARN] Font download failed"

cd "$AOSP_DIR"
for p in frameworks/base/patches/*.patch; do
    [ -f "$p" ] && git apply "$p" 2>/dev/null || echo "[WARN] Patch $p skipped"
done

# 8. 编译
echo ""
echo "[8/8] Building GSI (this will take 3-5 hours)..."
echo "      You can go for a coffee. Or several coffees."
echo ""
source build/envsetup.sh
lunch "$TARGET"
m -j$(nproc) systemimage

# 完成
SYSTEM_IMG=$(ls -1 out/target/product/*/system.img 2>/dev/null | head -1)
if [ -n "$SYSTEM_IMG" ]; then
    echo ""
    echo "=========================================="
    echo "  BUILD SUCCESS!"
    echo "=========================================="
    echo ""
    echo "Output: $SYSTEM_IMG"
    ls -lh "$SYSTEM_IMG"
    echo ""
    echo "刷入设备:"
    echo "  adb reboot bootloader"
    echo "  fastboot flash system $SYSTEM_IMG"
    echo "  fastboot reboot"
else
    echo "[ERROR] Build failed. Check log above."
    exit 1
fi
