#!/usr/bin/env bash
# ============================================================================
# ZephyrOS — Font Downloader
# ----------------------------------------------------------------------------
# 下载 OFL 许可证开源字体, 用于 ZephyrOS 字体集成.
# 所有字体均为开源 (OFL/Apache), 可商用, 不构成版权侵权.
#
# 字体映射:
#   ZephyrSans-Regular  <- Roboto (OFL, Google)
#   ZephyrSans-Medium   <- Roboto Medium (OFL)
#   ZephyrSans-Bold     <- Roboto Bold (OFL)
#   ZephyrRound-Regular <- Varela Round (OFL)
#   ZephyrCJK-Regular   <- Noto Sans CJK SC Regular (OFL)
#   ZephyrCJK-Bold      <- Noto Sans CJK SC Bold (OFL)
#
# 注: 字体文件名以 Zephyr* 命名以体现集成方式, 但字体本体来自上述开源项目,
#     遵循其 OFL 许可证 (见 OFL-LICENSE.txt).
# ============================================================================
set -euo pipefail

FONT_DIR="${1:-$(dirname "$(readlink -f "$0")")/files}"
mkdir -p "$FONT_DIR"
cd "$FONT_DIR"

echo "[ZephyrFonts] Downloading OFL fonts to: $PWD"

# Roboto family (Google Fonts OFL)
ROBOTO_BASE="https://github.com/googlefonts/roboto/raw/main/src/hinted"
download() {
    local url="$1"
    local out="$2"
    if [ -f "$out" ]; then
        echo "[SKIP] $out (exists)"
        return
    fi
    echo "[GET]  $out"
    curl -sSL -o "$out" "$url"
    if [ ! -s "$out" ]; then
        echo "[FAIL] $out — download failed"
        rm -f "$out"
        return 1
    fi
}

# Roboto
download "$ROBOTO_BASE/Roboto-Regular.ttf" "ZephyrSans-Regular.ttf"
download "$ROBOTO_BASE/Roboto-Medium.ttf" "ZephyrSans-Medium.ttf"
download "$ROBOTO_BASE/Roboto-Bold.ttf"   "ZephyrSans-Bold.ttf"

# Varela Round (圆体)
download "https://github.com/google/fonts/raw/main/ofl/varelaround/VarelaRound-Regular.ttf" \
         "ZephyrRound-Regular.ttf"

# Noto Sans CJK SC (中文字体, 体积较大, 仅下载 Regular/Bold)
NOTO_BASE="https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/SimplifiedChinese"
download "$NOTO_BASE/NotoSansCJKsc-Regular.otf" "ZephyrCJK-Regular.otf"
download "$NOTO_BASE/NotoSansCJKsc-Bold.otf"    "ZephyrCJK-Bold.otf"

echo "[OK] Fonts downloaded:"
ls -lh "$FONT_DIR"
