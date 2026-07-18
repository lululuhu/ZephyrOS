<div align="center">

# 🌿 ZephyrOS

**A clean, ad-free Android 14 GSI built on AOSP with PixelOS-style UI, Lawnchair launcher, and 8 original customization modules.**

*Pure · Fast · No telemetry · No commercial bloatware*

[![Build GSI](https://github.com/lululuhu/ZephyrOS/actions/workflows/build_gsi.yml/badge.svg)](https://github.com/lululuhu/ZephyrOS/actions/workflows/build_gsi.yml)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Android](https://img.shields.io/badge/Android-14-green.svg)](https://source.android.com/)
[![GSI](https://img.shields.io/badge/type-GSI-orange.svg)](https://source.android.com/docs/core/architecture/treble)

</div>

---

## ✨ Features

ZephyrOS is a community-driven Android 14 Generic System Image (GSI) that brings a Pixel-style experience with original customization features tailored for Chinese users.

### 🎨 PixelOS-Style UI
- **Material You** theming with Breeze green accent (`#2EB872`)
- Rounded corners on QS tiles, dialogs, notifications, volume panel
- Pixel-style lock screen clock and power menu
- Themed AOSP apps (Dialer, Messaging, Contacts, Calendar, Calculator, Clock)

### 🚀 Lawnchair Launcher
Replaces AOSP Launcher3 with [Lawnchair](https://github.com/LawnchairLauncher/lawnchair) (Apache 2.0) for a richer desktop experience.

### 🛠️ 8 Original Customization Modules (ZephyrParts)

| Module | Chinese Name | Key Features |
|---|---|---|
| **ZephyrStatus** | 清风状态栏 | Icon drag-reorder, net speed chip, weather chip, capsule notification preview |
| **FlowNotify** | 流光通知 | Smart grouping, heads-up duration, notification history, smart DND |
| **ZephyrGesture** | 清风手势 | 5-level edge swipe sensitivity, three-finger screenshot, one-handed mode |
| **ImmersiveFlow** | 全面屏手势 | Pill style (thin/thick/hidden), corner swipe actions, swipe-down for notifications |
| **AppVault** | 应用管家 | App locker, app hiding, app dual, app freezer, install source tracking |
| **PowerCore** | 续航引擎 | Deep doze, wakelock monitor, charge scheduling, app standby limits |
| **PrivacyGuard** | 隐私卫士 | Permission dashboard, camera/mic indicator, clipboard alert, network firewall |
| **ThemeStudio** | 主题工坊 | Color palette, font switcher, icon pack, corner radius adjustment |

### 🖼️ Original Resources
- **Boot animation**: Original Python-generated "Breeze Flow" animation (75 frames)
- **Wallpapers**: 6 original vector wallpapers (Breeze / Grove / Steam / Dewdrop / Horizon / Mint)
- **Fonts**: OFL-licensed font integration (Roboto / Varela Round / Noto Sans CJK)

### 🧹 Pure System Promise
- ❌ No ads of any kind
- ❌ No third-party commercial promotions
- ❌ No telemetry or remote data collection
- ❌ No pre-installed closed-source bloatware
- ✅ All features originally implemented

---

## 📱 Specifications

| Item | Value |
|---|---|
| Android version | 14 (android-14.0.0_r74) |
| Build target | `aosp_arm64-ab-userdebug` (GSI) |
| API level | 34 |
| Architecture | arm64-v8a |
| Build system | GitHub Actions (Ubuntu 22.04) |
| Build time | ~4.5 hours |
| Output size | ~1.5 GB (system.img) |

---

## 🚀 Build

### Option A: GitHub Actions (Recommended)

1. Fork or clone this repository
2. Go to **Actions** tab → **Build ZephyrOS GSI** → **Run workflow**
3. Wait ~4.5 hours
4. Download `system.img` from Artifacts

### Option B: Local Build

Requires: 64-bit Linux, 64GB free disk, 16GB RAM

```bash
git clone https://github.com/lululuhu/ZephyrOS.git
cd ZephyrOS
bash build_local.sh
```

---

## 📦 Flash to Device

> ⚠️ **Warning**: Flashing a GSI will wipe your system partition. Backup your data first. Your device must support Project Treble and have an unlockable bootloader.

```bash
# Reboot to bootloader
adb reboot bootloader

# Flash GSI to system partition
fastboot flash system system.img

# Reboot
fastboot reboot
```

### Compatibility
- Any Treble-enabled device (most devices released after 2018)
- A/B partition scheme devices
- Verify with Treble Info app before flashing

---

## 🏗️ Project Structure

```
ZephyrOS/
├── .github/workflows/      # GitHub Actions CI
├── build/                  # Build scripts
│   ├── build_gsi.sh
│   ├── optimize_disk.sh
│   ├── setup_env.sh
│   └── sign_gsi.sh
├── frameworks/base/
│   ├── patches/            # Framework patches (status bar, gesture)
│   └── packages/SystemUI/  # ZephyrOS SystemUI hooks
├── manifest/               # Local manifest (Lawnchair, PixelOS icons)
├── packages/apps/
│   ├── ZephyrParts/        # 8 customization modules
│   └── ZephyrWallpapers/   # 6 original wallpapers
└── vendor/zephyr/
    ├── bootanimation/      # Original boot animation generator
    ├── config/             # Branding, licenses
    ├── fonts/              # OFL font integration
    ├── icons/              # PixelOS icon pack overlay
    ├── launcher/           # Lawnchair configuration
    └── overlay/            # SystemUI/Settings/app themes
```

---

## 📜 License

ZephyrOS is licensed under **Apache License 2.0**.

See [LICENSE](LICENSE) for the full license text.

### Third-Party Components

| Component | License | Source |
|---|---|---|
| AOSP | Apache 2.0 | [android.googlesource.com](https://android.googlesource.com) |
| Lawnchair | Apache 2.0 | [github.com/LawnchairLauncher/lawnchair](https://github.com/LawnchairLauncher/lawnchair) |
| PixelOS icons | Apache 2.0 | [github.com/PixelOS-AOSP](https://github.com/PixelOS-AOSP) |
| Roboto font | Apache 2.0 | [github.com/googlefonts/roboto](https://github.com/googlefonts/roboto) |
| Varela Round font | OFL 1.1 | [fonts.google.com](https://fonts.google.com/specimen/Varela+Round) |
| Noto Sans CJK | OFL 1.1 | [github.com/notofonts/noto-cjk](https://github.com/notofonts/noto-cjk) |

---

## 🙏 Acknowledgments

ZephyrOS stands on the shoulders of giants. We gratefully acknowledge:

- **Android Open Source Project** — the foundation
- **Lawnchair Launcher** — the launcher
- **PixelOS** — icon design inspiration
- **Google Fonts** — Roboto, Varela Round, Noto Sans CJK

---

## 💬 Community

- 🐛 Bug reports: [GitHub Issues](https://github.com/lululuhu/ZephyrOS/issues)
- 💡 Feature requests: [GitHub Discussions](https://github.com/lululuhu/ZephyrOS/discussions)
- 🔀 Contributions: Pull requests welcome!

---

<div align="center">

**ZephyrOS** · 清风系统 · Pure Android, reimagined

Copyright © 2024-2026 ZephyrOS Project Contributors

</div>
