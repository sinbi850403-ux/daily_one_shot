"""
Play Store 피처 그래픽 생성 (1024×500 PNG)
python tool/gen_feature_graphic.py
"""
from PIL import Image, ImageDraw, ImageFont
import math, os

W, H = 1024, 500
out_path = "docs/feature_graphic.png"

# ── 한글 폰트 경로 탐색 ──────────────────────────────────────
FONT_CANDIDATES = [
    r"C:\Windows\Fonts\malgunbd.ttf",   # 맑은 고딕 볼드
    r"C:\Windows\Fonts\malgun.ttf",     # 맑은 고딕
    r"C:\Windows\Fonts\gulim.ttc",      # 굴림
    r"C:\Windows\Fonts\batang.ttc",     # 바탕
]

def find_font():
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            return p
    return None

FONT_PATH = find_font()
print(f"폰트: {FONT_PATH}")

def font(size, bold=False):
    if FONT_PATH:
        try:
            # bold면 malgunbd 시도
            bold_path = r"C:\Windows\Fonts\malgunbd.ttf"
            path = bold_path if bold and os.path.exists(bold_path) else FONT_PATH
            return ImageFont.truetype(path, size)
        except:
            pass
    return ImageFont.load_default()

# ── 이미지 생성 ──────────────────────────────────────────────
img = Image.new("RGB", (W, H), (0, 0, 0))
draw = ImageDraw.Draw(img)

# 배경 그라데이션 (위→아래)
for y in range(H):
    t = y / H
    r = int(46 * (1 - t) + 26 * t)
    g = int(28 * (1 - t) + 14 * t)
    b = int(18 * (1 - t) + 10 * t)
    draw.line([(0, y), (W, y)], fill=(r, g, b))

# 중앙 글로우 (왼쪽)
glow_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow_img)
for radius in range(280, 0, -1):
    alpha = int(30 * (1 - radius / 280))
    gd.ellipse([210 - radius, 250 - radius, 210 + radius, 250 + radius],
               fill=(176, 120, 80, alpha))
img = Image.alpha_composite(img.convert("RGBA"), glow_img).convert("RGB")
draw = ImageDraw.Draw(img)

# ── 카메라 아이콘 원 ─────────────────────────────────────────
CX, CY, CR = 210, 250, 140

# 바깥 글로우 링
for r in range(CR + 20, CR, -1):
    a = int(40 * (r - CR) / 20)
    # 그냥 원 그리기로 대체
draw.ellipse([CX-CR-5, CY-CR-5, CX+CR+5, CY+CR+5], fill=(120, 80, 50))
draw.ellipse([CX-CR, CY-CR, CX+CR, CY+CR], fill=(176, 120, 80))

# 카메라 바디 (흰색 둥근 사각형)
bx1, by1, bx2, by2 = CX-96, CY-48, CX+96, CY+68
draw.rounded_rectangle([bx1, by1, bx2, by2], radius=16, fill=(255, 255, 255))

# 뷰파인더 돌출부
draw.rounded_rectangle([CX-26, CY-64, CX+26, CY-44], radius=8, fill=(255, 255, 255))

# 플래시
draw.rounded_rectangle([CX+58, CY-38, CX+86, CY-22], radius=5, fill=(255, 230, 150))

# 렌즈 링
rings = [
    (46, (200, 160, 110)),
    (40, (235, 218, 195)),
    (33, (28, 16, 8)),
    (23, (46, 28, 14)),
    (13, (60, 40, 20)),
]
lx, ly = CX, CY + 14
for radius, color in rings:
    draw.ellipse([lx-radius, ly-radius, lx+radius, ly+radius], fill=color)
# 하이라이트
draw.ellipse([lx-18, ly-22, lx-6, ly-10], fill=(255, 255, 255, 120))
hl_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
hl_d = ImageDraw.Draw(hl_img)
hl_d.ellipse([lx-18, ly-22, lx-6, ly-10], fill=(255, 255, 255, 130))
hl_d.ellipse([lx-15, ly-19, lx-9, ly-13], fill=(255, 255, 255, 200))
img = Image.alpha_composite(img.convert("RGBA"), hl_img).convert("RGB")
draw = ImageDraw.Draw(img)

# ── 세로 구분선 ──────────────────────────────────────────────
for y in range(80, H - 80):
    t = (y - 80) / (H - 160)
    edge = min(t, 1 - t) * 2
    a = int(200 * edge)
    r_val = int(176 * a / 255 + img.getpixel((390, y))[0] * (1 - a/255))
    g_val = int(120 * a / 255 + img.getpixel((390, y))[1] * (1 - a/255))
    b_val = int(80  * a / 255 + img.getpixel((390, y))[2] * (1 - a/255))
    draw.point((390, y), fill=(r_val, g_val, b_val))
    draw.point((391, y), fill=(60, 40, 26))

# ── 텍스트 ──────────────────────────────────────────────────
TX = 425

# 앱 이름 (큰 볼드)
f_title = font(60, bold=True)
draw.text((TX, 110), "하루 한 장", font=f_title, fill=(255, 240, 220))

# 강조 라인
for x in range(TX, TX + 300):
    t = (x - TX) / 300
    r_v = int(176 * (1 - t) + 176 * t)
    g_v = int(120 * (1 - t))
    b_v = int(80  * (1 - t))
    draw.point((x, 185), fill=(r_v, g_v, b_v))
    draw.point((x, 186), fill=(r_v, g_v, b_v))
    draw.point((x, 187), fill=(r_v, g_v, b_v))

# 부제
f_sub = font(26, bold=True)
draw.text((TX, 198), "평생소장 사진 일기", font=f_sub, fill=(212, 165, 116))

# 설명 줄
f_body = font(16)
draw.text((TX, 242), "구독 없이  ·  서버 없이  ·  광고 없이(유료)", font=f_body, fill=(138, 96, 64))
draw.text((TX, 266), "한 번 사면 평생, 모든 데이터는 내 폰에만", font=f_body, fill=(138, 96, 64))

# ── 기능 뱃지 4개 ────────────────────────────────────────────
badges = [
    ("📷", "하루 한 장"),
    ("✨", "이날의 기억"),
    ("🗺", "지도 보기"),
    ("🔒", "생체 잠금"),
]
f_badge = font(13)
for i, (icon, label) in enumerate(badges):
    bx = TX + i * 138
    by = 310
    # 뱃지 배경
    badge_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(badge_img)
    bd.rounded_rectangle([bx, by, bx+120, by+82], radius=12,
                          fill=(176, 120, 80, 38), outline=(176, 120, 80, 100), width=1)
    img = Image.alpha_composite(img.convert("RGBA"), badge_img).convert("RGB")
    draw = ImageDraw.Draw(img)

    # 이모지 (Segoe UI Emoji 폰트 사용)
    try:
        f_emoji = ImageFont.truetype(r"C:\Windows\Fonts\seguiemj.ttf", 28)
    except:
        f_emoji = font(24)
    # 이모지 중앙 정렬
    draw.text((bx + 36, by + 12), icon, font=f_emoji, fill=(255, 255, 255), embedded_color=True)
    # 라벨
    draw.text((bx + 14, by + 56), label, font=f_badge, fill=(200, 144, 96))

# ── 가격 배지 ────────────────────────────────────────────────
price_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
pd = ImageDraw.Draw(price_img)
pd.rounded_rectangle([TX, 432, TX+216, 470], radius=19, fill=(176, 120, 80, 255))
img = Image.alpha_composite(img.convert("RGBA"), price_img).convert("RGB")
draw = ImageDraw.Draw(img)
f_price = font(16, bold=True)
draw.text((TX + 18, 442), "평생 이용권  ₩7,000", font=f_price, fill=(255, 240, 210))

# ── 저장 ────────────────────────────────────────────────────
os.makedirs("docs", exist_ok=True)
img.save(out_path, "PNG", optimize=True)
size_kb = os.path.getsize(out_path) // 1024
print(f"Done: {out_path}  ({size_kb} KB)")
