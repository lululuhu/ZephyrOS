#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ZephyrOS — Original Boot Animation Generator
=============================================
生成 ZephyrOS 原创开机动画的 PNG 帧序列, 并打包为 bootanimation.zip.

设计:
  part0 (30 帧, 0.5s @ 60fps): 风纹渐显
  part1 (45 帧, 0.75s @ 60fps): 风纹水平平移 + 文字渐显

依赖:
  - Python 3.8+
  - Pillow (PIL): pip install Pillow

用法:
  python3 generate_bootanimation.py
  产出: bootanimation.zip

无 Pillow 时也可降级为生成纯色占位帧, 保证 CI 可继续构建.
"""
import os
import sys
import zipfile
import struct
import zlib

# 动画参数
WIDTH, HEIGHT, FPS = 1080, 1920, 60
PART0_FRAMES = 30
PART1_FRAMES = 45

# 清风主题色
COLOR_BG = (250, 252, 250)        # 极浅米白背景
COLOR_GREEN = (46, 184, 114)      # 清风绿
COLOR_GREEN_LIGHT = (156, 229, 197)  # 浅薄荷
COLOR_TEXT = (30, 30, 30)         # 文字深灰

OUT_DIR = os.path.dirname(os.path.abspath(__file__))


# ----------------------------------------------------------------------------
# Pillow 可用: 使用矢量绘制 + 抗锯齿
# ----------------------------------------------------------------------------
def has_pillow():
    try:
        from PIL import Image, ImageDraw  # noqa: F401
        return True
    except ImportError:
        return False


def draw_frame_pillow(phase, frame_idx, total_frames):
    """使用 Pillow 绘制单帧"""
    from PIL import Image, ImageDraw

    img = Image.new("RGB", (WIDTH, HEIGHT), COLOR_BG)
    draw = ImageDraw.Draw(img)

    progress = frame_idx / max(total_frames - 1, 1)

    if phase == 0:
        # 渐显: 三条风纹的不透明度从 0 到 1
        alpha = progress
        color = blend(COLOR_BG, COLOR_GREEN, alpha)
    else:
        # 平移: 三条风纹水平偏移
        offset_x = int(progress * 200)
        color = COLOR_GREEN
        # 文字渐显 (后半段)
        text_alpha = max(0, (progress - 0.5) * 2)

    # 三条风纹 (与 ZephyrParts 图标呼应)
    base_y = HEIGHT // 2 - 80
    for i, dy in enumerate([-80, 0, 80]):
        y = base_y + dy
        if phase == 0:
            draw_wind_curve(draw, 200, y, 880, y, color, alpha=alpha)
        else:
            draw_wind_curve(draw, 200 + offset_x, y, 880 + offset_x, y, color, alpha=1.0)

    # ZephyrOS 文字 (part1 后半段渐显)
    if phase == 1:
        text_color = blend(COLOR_BG, COLOR_TEXT, text_alpha)
        draw_text_centered(draw, WIDTH // 2, HEIGHT // 2 + 200,
                           "ZephyrOS", text_color, size=72)
        draw_text_centered(draw, WIDTH // 2, HEIGHT // 2 + 290,
                           "清风", text_color, size=36)

    return img


def draw_wind_curve(draw, x1, y1, x2, y2, color, alpha=1.0):
    """绘制一条贝塞尔风纹曲线 (近似手绘风纹)"""
    # 用三次贝塞尔近似: 起伏波浪
    points = []
    steps = 60
    for i in range(steps + 1):
        t = i / steps
        # 控制点构造波浪
        ctrl_offset = 30 if int(t * 4) % 2 == 0 else -30
        # 二次贝塞尔
        x = (1 - t) ** 2 * x1 + 2 * (1 - t) * t * (x1 + x2) / 2 + t ** 2 * x2
        y = (1 - t) ** 2 * y1 + 2 * (1 - t) * t * (y1 + ctrl_offset) + t ** 2 * y2
        points.append((x, y))

    if len(points) >= 2:
        # 通过线段连接近似曲线
        for i in range(len(points) - 1):
            draw.line([points[i], points[i + 1]], fill=color, width=8)


def draw_text_centered(draw, x, y, text, color, size=48):
    """简易居中文字 (Pillow 默认字体)"""
    try:
        from PIL import ImageFont
        font = ImageFont.load_default()
    except Exception:
        font = None
    try:
        bbox = draw.textbbox((0, 0), text, font=font)
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
    except Exception:
        w, h = len(text) * size // 2, size
    draw.text((x - w // 2, y - h // 2), text, fill=color, font=font)


def blend(c1, c2, t):
    return tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3))


# ----------------------------------------------------------------------------
# 无 Pillow 降级: 生成最简 PNG (纯色)
# ----------------------------------------------------------------------------
def write_png_solid(filename, width, height, rgb):
    """生成纯色 PNG (无依赖)"""
    def png_chunk(chunk_type, data):
        c = chunk_type + data
        crc = zlib.crc32(c) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + c + struct.pack(">I", crc)

    # PNG 头
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    # 像素数据 (每行起一个 filter byte = 0)
    raw = bytearray()
    for _ in range(height):
        raw.append(0)
        raw.extend(bytes(rgb) * width)
    compressed = zlib.compress(bytes(raw))

    with open(filename, "wb") as f:
        f.write(sig)
        f.write(png_chunk(b"IHDR", ihdr))
        f.write(png_chunk(b"IDAT", compressed))
        f.write(png_chunk(b"IEND", b""))


def generate():
    print("[ZephyrBoot] Generating original boot animation...")

    use_pillow = has_pillow()
    if not use_pillow:
        print("[ZephyrBoot] WARN: Pillow not found, falling back to solid frames.")
        print("[ZephyrBoot]        Install Pillow for full animation: pip install Pillow")

    # 临时帧目录
    part0_dir = os.path.join(OUT_DIR, "part0")
    part1_dir = os.path.join(OUT_DIR, "part1")
    os.makedirs(part0_dir, exist_ok=True)
    os.makedirs(part1_dir, exist_ok=True)

    # 生成 part0
    for i in range(PART0_FRAMES):
        fname = os.path.join(part0_dir, f"frame_{i + 1:04d}.png")
        if use_pillow:
            img = draw_frame_pillow(0, i, PART0_FRAMES)
            img.save(fname)
        else:
            # 渐显效果: 颜色插值
            alpha = i / max(PART0_FRAMES - 1, 1)
            color = blend(COLOR_BG, COLOR_GREEN, alpha)
            write_png_solid(fname, WIDTH, HEIGHT, color)

    # 生成 part1
    for i in range(PART1_FRAMES):
        fname = os.path.join(part1_dir, f"frame_{i + 1:04d}.png")
        if use_pillow:
            img = draw_frame_pillow(1, i, PART1_FRAMES)
            img.save(fname)
        else:
            # 平移效果: 用偏移色块
            offset = int((i / max(PART1_FRAMES - 1, 1)) * 200)
            color = blend(COLOR_BG, COLOR_GREEN_LIGHT, 0.5)
            write_png_solid(fname, WIDTH, HEIGHT, color)

    # 打包 zip
    zip_path = os.path.join(OUT_DIR, "bootanimation.zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        # desc.txt 必须为 zip 第一个文件
        desc_path = os.path.join(OUT_DIR, "desc.txt")
        if os.path.exists(desc_path):
            zf.write(desc_path, "desc.txt")

        for part_dir, prefix in [(part0_dir, "part0"), (part1_dir, "part1")]:
            for fname in sorted(os.listdir(part_dir)):
                if fname.endswith(".png"):
                    zf.write(os.path.join(part_dir, fname),
                             f"{prefix}/{fname}")

    print(f"[ZephyrBoot] OK: {zip_path}")
    print(f"[ZephyrBoot] part0: {PART0_FRAMES} frames, part1: {PART1_FRAMES} frames")

    # 清理临时帧 (zip 已打包, 保留帧会增大仓库体积)
    # 注: 实际 CI 中可以选择保留以加速增量构建
    return zip_path


if __name__ == "__main__":
    generate()
