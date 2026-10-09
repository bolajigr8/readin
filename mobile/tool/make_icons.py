"""Generates the ReadIn launcher icon (adaptive + legacy + monochrome) and the
splash logo with Pillow. Usage:  python3 tool/make_icons.py
Writes into android/app/src/main/res and assets/icons|images."""
import os
from PIL import Image, ImageDraw, ImageFont

ORANGE = (249, 115, 22, 255)
DARK = (10, 10, 10, 255)
WHITE = (255, 255, 255, 255)
CREAM = (255, 237, 220, 255)
AMBER = (251, 191, 36, 255)
FONT = '/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf'
RES = 'android/app/src/main/res'
S = 2048  # supersampled canvas, reduced at the end


def bezier(p0, p1, p2, n=40):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])
            for t in [i / n for i in range(n + 1)]]


def art(mono=False):
    """The logo mark (R above an open book) on a transparent 1024-unit canvas."""
    k = S / 1024
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    page_l = WHITE if not mono else WHITE
    page_r = CREAM if not mono else WHITE

    def pts(poly):
        return [(x * k, y * k) for x, y in poly]

    gap = 7
    # left page
    left = (bezier((512 - gap, 585), (350, 520), (170, 548)) + [(170, 835)] +
            bezier((170, 835), (350, 808), (512 - gap, 880))[::-1][::-1])
    left = bezier((512 - gap, 585), (350, 520), (170, 548)) + bezier((170, 835), (350, 805), (512 - gap, 880))[::1]
    # right page (mirror)
    right = [(1024 - x, y) for x, y in left]
    d.polygon(pts(left), fill=page_l)
    d.polygon(pts(right), fill=page_r)

    if not mono:
        # text lines on the pages
        for i in range(4):
            y = 650 + i * 46
            d.line(pts([(235, y), (440, y - 14 + 6 * (i % 2))]), fill=ORANGE, width=int(11 * k))
            d.line(pts([(1024 - 440, y - 14 + 6 * (i % 2)), (1024 - 235, y)]), fill=ORANGE, width=int(11 * k))

    # the R
    font = ImageFont.truetype(FONT, int(470 * k))
    bbox = d.textbbox((0, 0), 'R', font=font)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = 512 * k - w / 2 - bbox[0]
    y = 330 * k - h / 2 - bbox[1]
    d.text((x, y), 'R', font=font, fill=WHITE if mono else DARK)

    if not mono:
        # amber bookmark ribbon on the right page
        ribbon = [(832, 552), (832, 700), (864, 672), (896, 700), (896, 560)]
        d.polygon(pts(ribbon), fill=AMBER)
    return img


def fit(img, box, size):
    """Crop the artwork to its bounding box then scale it into `box` px, centred on a size×size canvas."""
    bb = img.getbbox()
    a = img.crop(bb)
    scale = box / max(a.size)
    a = a.resize((max(1, int(a.width * scale)), max(1, int(a.height * scale))), Image.LANCZOS)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(a, ((size - a.width) // 2, (size - a.height) // 2), a)
    return out


def rounded(size, radius, color):
    big = Image.new('RGBA', (size * 2, size * 2), (0, 0, 0, 0))
    ImageDraw.Draw(big).rounded_rectangle((0, 0, size * 2 - 1, size * 2 - 1), radius * 2, fill=color)
    return big.resize((size, size), Image.LANCZOS)


def save(img, path, size=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if size:
        img = img.resize((size, size), Image.LANCZOS)
    img.save(path)


main = art()
mono = art(mono=True)

# ── master icon 1024 (rounded tile, art fills ~70 %) ───────────────────────
tile = rounded(1024, 230, ORANGE)
mark = fit(main, 700, 1024)
master = tile.copy()
master.alpha_composite(mark)
save(master, 'assets/icons/icon.png')

# adaptive layers (108 dp canvas, safe zone = centre 66 %): art ≈ 60 % of canvas
save(fit(main, 620, 1024), 'assets/icons/android-icon-foreground.png')
save(Image.new('RGBA', (1024, 1024), ORANGE), 'assets/icons/android-icon-background.png')
save(fit(mono, 620, 1024), 'assets/icons/android-icon-monochrome.png')

dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
fg = Image.open('assets/icons/android-icon-foreground.png')
bg = Image.open('assets/icons/android-icon-background.png')
mo = Image.open('assets/icons/android-icon-monochrome.png')
for dname, m in dens.items():
    save(master, f'{RES}/mipmap-{dname}/ic_launcher.png', int(48 * m))
    save(master, f'{RES}/mipmap-{dname}/ic_launcher_round.png', int(48 * m))
    save(fg, f'{RES}/mipmap-{dname}/ic_launcher_foreground.png', int(108 * m))
    save(bg, f'{RES}/mipmap-{dname}/ic_launcher_background.png', int(108 * m))
    save(mo, f'{RES}/mipmap-{dname}/ic_launcher_monochrome.png', int(108 * m))

# ── splash: the logo tile on the dark launch screen ────────────────────────
splash = rounded(1024, 230, ORANGE)
splash.alpha_composite(fit(main, 700, 1024))
save(splash, 'assets/images/splash-icon.png')
for dname, m in dens.items():
    save(splash, f'{RES}/drawable-{dname}/splash_icon.png', int(160 * m))
# Android 12+: icon inside a 288 dp circle; keep the logo in the inner 192 dp
canvas = Image.new('RGBA', (1152, 1152), (0, 0, 0, 0))
logo = splash.resize((560, 560), Image.LANCZOS)
canvas.alpha_composite(logo, ((1152 - 560) // 2, (1152 - 560) // 2))
os.makedirs(f'{RES}/drawable-nodpi', exist_ok=True)
canvas.save(f'{RES}/drawable-nodpi/splash_icon_android12.png')

# preview sheet (not shipped)
prev = Image.new('RGBA', (1500, 560), (24, 24, 27, 255))
prev.alpha_composite(master.resize((480, 480), Image.LANCZOS), (30, 40))
circ = Image.new('RGBA', (480, 480), (0, 0, 0, 0))
m = Image.new('L', (480, 480), 0)
ImageDraw.Draw(m).ellipse((0, 0, 479, 479), fill=255)
adaptive = Image.new('RGBA', (480, 480), ORANGE)
adaptive.alpha_composite(fg.resize((480, 480), Image.LANCZOS))
circ.paste(adaptive, (0, 0), m)
prev.alpha_composite(circ, (540, 40))
sp = Image.new('RGBA', (300, 520), (10, 10, 10, 255))
sp.alpha_composite(splash.resize((150, 150), Image.LANCZOS), (75, 150))
prev.alpha_composite(sp, (1100, 20))
prev.convert('RGB').save('/tmp/icon_preview.png')
print('icons written')
