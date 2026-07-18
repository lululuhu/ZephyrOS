#!/usr/bin/env python3
"""
Generate a comprehensive <remove-project> manifest for GSI-only builds.

Strategy: GSI (Generic System Image) runs on top of a device's existing
vendor partition. We do NOT need:
  - device/google/<pixel-codename>   (device-specific trees)
  - device/amlogic, device/linaro    (dev boards)
  - device/generic/goldfish, mini-emulator-*, vulkan-cereal  (emulator)
  - kernel/prebuilts/*               (GSI uses device kernel)
  - trusty/*                         (Trusty TEE OS, device-specific)
  - hardware/qcom/*, broadcom/*, nxp/*  (vendor HALs, device-specific)

We KEEP:
  - device/generic/arm64, x86_64, car, uml  (needed for GSI build targets)
  - device/google/gs-common, trout  (shared infra)
  - hardware/interfaces, libhardware, libhardware_legacy, ril  (framework deps)
  - All framework/, packages/, system/, art/, libcore/, etc.
"""
import xml.etree.ElementTree as ET
import sys

MANIFEST = "/tmp/aosp_manifest_repo/default.xml"
CURRENT_REMOVE = "/workspace/manifest/remove-projects.xml"

# Read already-removed project names from current remove-projects.xml
already_removed = set()
try:
    cur_tree = ET.parse(CURRENT_REMOVE)
    for p in cur_tree.getroot().findall("remove-project"):
        name = p.get("name")
        if name:
            already_removed.add(name)
except Exception as e:
    print(f"WARN: could not parse current remove-projects.xml: {e}", file=sys.stderr)

# Whitelist: projects that LOOK like they should be removed but are needed
KEEP = {
    "device/generic/arm64",
    "device/generic/armv7-a-neon",
    "device/generic/car",
    "device/generic/uml",
    "device/generic/x86_64",
    "device/generic/goldfish-opengl",  # only if exists; usually fine to keep
    "device/generic/opengl-transport",
    "device/google/gs-common",
    "device/google/trout",
    "hardware/interfaces",  # HIDL/AIDL interfaces — NEEDED for GSI build
    "hardware/libhardware",  # NEEDED for GSI build
    "hardware/libhardware_legacy",  # NEEDED for GSI build
    "hardware/ril",  # NEEDED for telephony framework
    "hardware/google/apf",  # small, sometimes needed
    "hardware/google/interfaces",  # AIDL interfaces, sometimes needed
}

# Prefix patterns for projects to remove (GSI does not need these)
REMOVE_PREFIXES = [
    # Device trees — Pixel & vendor specific
    "device/google/akita",
    "device/google/amlogic",
    "device/google/barbet",
    "device/google/bluejay",
    "device/google/bramble",
    "device/google/caimito",
    "device/google/comet",
    "device/google/coral",
    "device/google/felix",
    "device/google/gs101",
    "device/google/gs201",
    "device/google/lynx",
    "device/google/pantah",
    "device/google/raviole",
    "device/google/redbull",
    "device/google/redfin",
    "device/google/shusky",
    "device/google/sunfish",
    "device/google/tangorpro",
    "device/google/zuma",
    "device/google/zumapro",
    "device/google/zeus",
    "device/google/oriole",
    "device/google/sepolicy",
    "device/google/contexthub",
    "device/google/atv",
    "device/google/bonito",
    "device/google/crosshatch",
    "device/google/cuttlefish",
    "device/google/sargo",
    "device/google/muskie",
    "device/google/taimen",
    "device/google/wahoo",
    "device/google/vesper",
    "device/amlogic/",
    "device/linaro/",
    "device/generic/goldfish",
    "device/generic/mini-emulator",
    "device/generic/vulkan-cereal",
    "device/generic/qemu",
    "device/ti/",
    "device/samsung/",
    "device/sony/",
    "device/nxp/",
    "device/mediatek/",
    "device/intel/",
    # Kernel prebuilts — GSI uses the device's existing kernel
    "kernel/prebuilts/",
    "kernel/tests",
    # Trusty TEE OS — device-specific
    "trusty/",
    # Vendor HALs — device-specific
    "hardware/qcom/",
    "hardware/broadcom/",
    "hardware/nxp/",
    "hardware/akm/",
    "hardware/google/easel",
    "hardware/google/av",
    "hardware/invensense",
    "hardware/marvell",
    "hardware/mediatek/",
    "hardware/rockchip/",
    "hardware/samsung/",
    "hardware/st/",
    "hardware/ti/",
]

# Parse the AOSP manifest
tree = ET.parse(MANIFEST)
root = tree.getroot()

all_projects = []
for p in root.findall("project"):
    name = p.get("name")
    if name:
        all_projects.append(name)

to_remove = []
for name in all_projects:
    if name in already_removed:
        continue
    if name in KEEP:
        continue
    for prefix in REMOVE_PREFIXES:
        if name.startswith(prefix):
            to_remove.append(name)
            break

# Sort for readability
to_remove.sort()

# Print summary
print(f"Total projects in AOSP manifest: {len(all_projects)}", file=sys.stderr)
print(f"Already removed (current file):  {len(already_removed)}", file=sys.stderr)
print(f"New projects to remove:          {len(to_remove)}", file=sys.stderr)
print(f"Total after merge:               {len(already_removed) + len(to_remove)}", file=sys.stderr)
print("---", file=sys.stderr)
from collections import Counter
breakdown = Counter()
for n in to_remove:
    top = n.split("/")[1] if "/" in n else n
    breakdown[top] += 1
for k, v in sorted(breakdown.items()):
    print(f"  {k}: {v}", file=sys.stderr)

# Write the merged remove-project list to stdout (XML)
print('<?xml version="1.0" encoding="UTF-8"?>')
print('<!--')
print('    ZephyrOS — AOSP Source Slimming Manifest (v3, aggressive)')
print('    Generated from android-14.0.0_r74/default.xml.')
print('')
print('    Goal: fit AOSP source + build output within GitHub Actions')
print('    runner disk (~84 GB after cleanup). Removes ~25 GB of')
print('    device/kernel/trusty/hardware trees that GSI builds do not need.')
print('')
print('    KEEP (whitelisted):')
print('      device/generic/{arm64,armv7-a-neon,car,uml,x86_64}')
print('      device/google/{gs-common,trout}')
print('      hardware/{interfaces,libhardware,libhardware_legacy,ril}')
print('      All framework/packages/system/art/libcore projects')
print('-->')
print('<manifest>')
print('')

# Verify every project name actually exists in AOSP manifest
all_set = set(all_projects)
def emit(name):
    if name not in all_set:
        print(f'    <!-- WARN: project not in manifest, skipped: {name} -->', file=sys.stderr)
        return
    print(f'    <remove-project name="{name}" />')

print('    <!-- ===== A. Testing suites (~5 GB) ===== -->')
TEST_PREFIXES = ("platform/test", "platform/cts", "platform/platform_testing")
for name in sorted(already_removed):
    if name.startswith(TEST_PREFIXES):
        emit(name)

print('')
print('    <!-- ===== B. PDK (~1 GB) ===== -->')
for name in sorted(already_removed):
    if name == "platform/pdk":
        emit(name)

print('')
print('    <!-- ===== C. Emulator prebuilts (~3 GB) ===== -->')
EMU_KEYWORDS = ("android-emulator", "qemu-kernel")
for name in sorted(already_removed):
    if any(k in name for k in EMU_KEYWORDS):
        emit(name)

print('')
print('    <!-- ===== D. SDK / dev tools prebuilts (~2 GB) ===== -->')
SDK_KEYWORDS = ("cmdline-tools", "devtools", "bundletool", "checkstyle",
                "ktlint", "manifest-merger", "checkcolor", "gradle-plugin",
                "abi-dumps")
for name in sorted(already_removed):
    if any(k in name for k in SDK_KEYWORDS):
        emit(name)

print('')
print('    <!-- ===== E. Trade Federation / misc test tools ===== -->')
MISC_KEYWORDS = ("tradefederation", "fat32lib")
for name in sorted(already_removed):
    if any(k in name for k in MISC_KEYWORDS):
        emit(name)

print('')
print('    <!-- ===== F. Docs & samples (~0.5 GB) ===== -->')
DOC_PREFIX = "platform/developers"
for name in sorted(already_removed):
    if name.startswith(DOC_PREFIX):
        emit(name)

print('')
print('    <!-- ================================================================ -->')
print('    <!-- ===== G. NEW (v3): Device trees — Pixel & vendor-specific ===== -->')
print('    <!--      GSI does not need device-specific trees.                  -->')
print('    <!-- ================================================================ -->')
print('')

def section(title, predicate):
    items = [n for n in to_remove if predicate(n)]
    if not items:
        return
    # NOTE: XML comments cannot contain "--" inside, so use single dashes only
    print(f'    <!-- {title} ({len(items)} projects) -->')
    for n in items:
        emit(n)
    print('')

section("Google Pixel devices (akita..zumapro)",
        lambda n: n.startswith("device/google/") and n not in ("device/google/gs-common", "device/google/trout"))
section("Dev boards (amlogic, linaro, ti, samsung, etc.)",
        lambda n: n.startswith(("device/amlogic", "device/linaro", "device/ti", "device/samsung", "device/sony", "device/nxp", "device/mediatek", "device/intel")))
section("Emulator device configs (goldfish, mini-emulator, vulkan-cereal, qemu)",
        lambda n: n.startswith(("device/generic/goldfish", "device/generic/mini-emulator", "device/generic/vulkan-cereal", "device/generic/qemu")))

print('    <!-- ================================================================ -->')
print('    <!-- ===== H. Kernel prebuilts (GSI uses device kernel) =========== -->')
print('    <!-- ================================================================ -->')
section("kernel/prebuilts/* and kernel/tests",
        lambda n: n.startswith("kernel/"))

print('    <!-- ================================================================ -->')
print('    <!-- ===== I. Trusty TEE OS (device-specific) ===================== -->')
print('    <!-- ================================================================ -->')
section("trusty/*",
        lambda n: n.startswith("trusty/"))

print('    <!-- ================================================================ -->')
print('    <!-- ===== J. Vendor HALs (device-specific) ======================= -->')
print('    <!-- ================================================================ -->')
section("hardware/qcom, broadcom, nxp, mediatek, rockchip, samsung, st, ti, akm, invensense, marvell",
        lambda n: n.startswith(("hardware/qcom", "hardware/broadcom", "hardware/nxp",
                                 "hardware/mediatek", "hardware/rockchip", "hardware/samsung",
                                 "hardware/st", "hardware/ti", "hardware/akm", "hardware/invensense",
                                 "hardware/marvell")))
section("hardware/google (easel, av — device-specific)",
        lambda n: n.startswith(("hardware/google/easel", "hardware/google/av")))

print('</manifest>')
