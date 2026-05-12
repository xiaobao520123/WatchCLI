"""Generate the WatchCLI app icon at all required sizes.

Aesthetic: full-bleed dark gradient background (works under both iOS's
squircle mask and watchOS's circle mask), with a giant centered ">_"
prompt rendered in Menlo Bold. The base 1024 master is supersampled and
downscaled with LANCZOS for sharp edges at every required size.
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os, sys

OUT_DIR = sys.argv[1]
os.makedirs(OUT_DIR, exist_ok=True)

BG_INNER  = (32, 26, 38)
BG_OUTER  = (10, 10, 14)
ACCENT    = (255, 122, 61)        # #FF7A3D
GLOW      = (255, 122, 61, 100)

SIZE = 1024
SS   = 4
W    = SIZE * SS
TEXT = ">_"

# Menlo.ttc is a TrueType collection; index 1 is the Bold face.
FONT_PATH = "/System/Library/Fonts/Menlo.ttc"
FONT_INDEX = 1

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def radial_background(w):
    img = Image.new("RGB", (w, w), BG_OUTER)
    px = img.load()
    cx = cy = w / 2
    max_r = (cx * cx + cy * cy) ** 0.5
    for y in range(w):
        for x in range(w):
            r = (((x - cx) ** 2 + (y - cy) ** 2) ** 0.5) / max_r
            t = min(1.0, max(0.0, (r - 0.05) * 1.20))
            px[x, y] = lerp(BG_INNER, BG_OUTER, t)
    return img

def fit_font(text, target_width):
    """Pick the largest Menlo Bold size whose width fits target_width."""
    lo, hi = 50, 4000
    best = lo
    while lo <= hi:
        mid = (lo + hi) // 2
        f = ImageFont.truetype(FONT_PATH, mid, index=FONT_INDEX)
        bbox = f.getbbox(text)
        w_ = bbox[2] - bbox[0]
        if w_ <= target_width:
            best = mid; lo = mid + 1
        else:
            hi = mid - 1
    return ImageFont.truetype(FONT_PATH, best, index=FONT_INDEX)

def render_master():
    img = radial_background(W)
    draw = ImageDraw.Draw(img, "RGBA")

    target_width = int(W * 0.66)
    font = fit_font(TEXT, target_width)
    bbox = font.getbbox(TEXT)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    # bbox[0], bbox[1] are the text's offset from origin; account for them.
    tx = (W - tw) // 2 - bbox[0]
    ty = (W - th) // 2 - bbox[1] - int(W * 0.02)  # tiny optical lift

    # Soft glow layer.
    glow_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    g = ImageDraw.Draw(glow_layer)
    g.text((tx, ty), TEXT, font=font, fill=GLOW)
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=W * 0.022))
    img.paste(glow_layer, (0, 0), glow_layer)

    # Crisp glyphs on top.
    crisp = ImageDraw.Draw(img)
    crisp.text((tx, ty), TEXT, font=font, fill=ACCENT)

    return img

master = render_master().resize((SIZE, SIZE), Image.LANCZOS)

def export(path, size):
    out = master.resize((size, size), Image.LANCZOS)
    out.save(path, "PNG", optimize=True)
    return os.path.basename(path)

ios_specs = [
    ("ios-1024.png", 1024),
    ("ios-180.png",  180),
    ("ios-167.png",  167),
    ("ios-152.png",  152),
    ("ios-120.png",  120),
    ("ios-87.png",   87),
    ("ios-80.png",   80),
    ("ios-76.png",   76),
    ("ios-58.png",   58),
    ("ios-40.png",   40),
]

watch_specs = [
    ("watch-1024.png", 1024),
    ("watch-216.png",  216),
    ("watch-172.png",  172),
    ("watch-100.png",  100),
    ("watch-92.png",   92),
    ("watch-87.png",   87),
    ("watch-80.png",   80),
    ("watch-58.png",   58),
    ("watch-55.png",   55),
    ("watch-48.png",   48),
    ("watch-44.png",   44),
    ("watch-40.png",   40),
    ("watch-29.png",   29),
]

for name, size in ios_specs + watch_specs:
    print(export(os.path.join(OUT_DIR, name), size))
