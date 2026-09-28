#!/usr/bin/env python3
"""Draws the launcher icon (gold question mark on a stage-blue disc) and
writes all Android mipmap sizes plus the 512 px Play Store icon.

Requires Pillow:  pip install pillow && python3 tool/icon/make_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
S = 1024
GOLD = (245, 197, 66)
GOLD_DEEP = (184, 134, 11)


def font(size):
    for p in ('/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf',
              '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def radial(size, inner, outer):
    img = Image.new('RGB', (size, size), outer)
    d = ImageDraw.Draw(img)
    steps = 120
    for i in range(steps):
        t = i / steps
        r = int(size * 0.75 * (1 - t))
        c = tuple(int(outer[k] + (inner[k] - outer[k]) * t) for k in range(3))
        d.ellipse([size / 2 - r, size * 0.42 - r, size / 2 + r, size * 0.42 + r], fill=c)
    return img


def make():
    bg = radial(S, (48, 72, 180), (5, 10, 38))
    # Spotlight beams.
    beams = Image.new('L', (S, S), 0)
    bd = ImageDraw.Draw(beams)
    for x0, x1 in ((0.2, 0.05), (0.5, 0.5), (0.8, 0.95)):
        bd.polygon([(S * x0, -10), (S * x1 - 170, S), (S * x1 + 170, S)], fill=38)
    beams = beams.filter(ImageFilter.GaussianBlur(40))
    bg = Image.composite(Image.new('RGB', (S, S), (160, 190, 255)), bg, beams)

    # Gold ring.
    ring = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    m = 70
    rd.ellipse([m, m, S - m, S - m], outline=GOLD + (255,), width=42)
    rd.ellipse([m + 58, m + 58, S - m - 58, S - m - 58], outline=GOLD_DEEP + (200,), width=10)

    # Glowing question mark.
    q = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    qd = ImageDraw.Draw(q)
    f = font(640)
    box = qd.textbbox((0, 0), '?', font=f)
    w, h = box[2] - box[0], box[3] - box[1]
    pos = ((S - w) / 2 - box[0], (S - h) / 2 - box[1] - 20)
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).text(pos, '?', font=f, fill=GOLD + (200,))
    glow = glow.filter(ImageFilter.GaussianBlur(28))
    qd.text(pos, '?', font=f, fill=GOLD + (255,), stroke_width=10, stroke_fill=GOLD_DEEP + (255,))

    icon = bg.convert('RGBA')
    for layer in (ring, glow, q):
        icon.alpha_composite(layer)

    # Circular launcher mask (legacy icons) + square Play Store icon.
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, S, S], fill=255)
    round_icon = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    round_icon.paste(icon, (0, 0), mask)

    sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for name, px in sizes.items():
        out = RES / f'mipmap-{name}' / 'ic_launcher.png'
        round_icon.resize((px, px), Image.LANCZOS).save(out)
    store = ROOT / 'store'
    store.mkdir(exist_ok=True)
    icon.convert('RGB').resize((512, 512), Image.LANCZOS).save(store / 'icon-512.png')
    print('icons written')


if __name__ == '__main__':
    make()
