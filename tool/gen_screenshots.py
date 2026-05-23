"""
Play Store 목업 스크린샷 생성 (1080×1920)
python tool/gen_screenshots.py
"""
from PIL import Image, ImageDraw, ImageFont
import os, math, random

W, H = 1080, 1920
OUT = "docs/screenshots"
os.makedirs(OUT, exist_ok=True)

# ── 폰트 ─────────────────────────────────────────────────────
def font(size, bold=False):
    candidates = [
        (r"C:\Windows\Fonts\malgunbd.ttf", True),
        (r"C:\Windows\Fonts\malgun.ttf", False),
    ]
    for path, is_bold in candidates:
        if os.path.exists(path):
            if bold == is_bold or not bold:
                try: return ImageFont.truetype(path, size)
                except: pass
    return ImageFont.load_default()

def emoji_font(size=36):
    p = r"C:\Windows\Fonts\seguiemj.ttf"
    if os.path.exists(p):
        try: return ImageFont.truetype(p, size)
        except: pass
    return font(size)

# ── 공통 색상 ─────────────────────────────────────────────────
BG       = (250, 245, 240)       # 연한 크림
BG_DARK  = (44,  28,  16)        # 짙은 갈색
SURFACE  = (255, 255, 255)       # 흰색 카드
GOLD     = (176, 120, 80)        # 주색
GOLD_L   = (212, 165, 116)       # 밝은 금색
GOLD_D   = (122, 82,  48)        # 어두운 금색
TEXT_PRI = (40,  24,  12)        # 주 텍스트
TEXT_SEC = (120, 90,  64)        # 보조 텍스트
DIVIDER  = (230, 220, 210)       # 구분선

# ── 헬퍼 ─────────────────────────────────────────────────────
def new_phone():
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    # 상태바
    d.rectangle([0, 0, W, 100], fill=BG_DARK)
    d.text((60, 30), "9:41", font=font(36, bold=True), fill=(255,245,235))
    d.text((W-220, 30), "●●● 🔋", font=emoji_font(32), fill=(255,245,235), embedded_color=True)
    return img, d

def draw_appbar(d, title, subtitle=None):
    d.rectangle([0, 100, W, 220], fill=BG_DARK)
    f = font(44, bold=True)
    d.text((60, 130), title, font=f, fill=(255, 240, 220))
    if subtitle:
        d.text((60, 182), subtitle, font=font(28), fill=GOLD_L)

def rounded_rect(d, x1, y1, x2, y2, r=24, fill=SURFACE, outline=None, width=2):
    d.rounded_rectangle([x1, y1, x2, y2], radius=r, fill=fill,
                         outline=outline, width=width)

def card(d, x1, y1, x2, y2, r=28):
    # 그림자 효과
    d.rounded_rectangle([x1+6, y1+6, x2+6, y2+6], radius=r, fill=(200,185,170))
    d.rounded_rectangle([x1, y1, x2, y2], radius=r, fill=SURFACE)

# ═══════════════════════════════════════════════════════════════
# 스크린샷 1: 오늘 화면 (사진 + 메모 입력)
# ═══════════════════════════════════════════════════════════════
def make_today():
    img, d = new_phone()
    draw_appbar(d, "오늘", "2026년 5월 23일 금요일")

    # 날씨 뱃지
    rounded_rect(d, W-280, 128, W-60, 204, r=36,
                  fill=(60, 40, 20), outline=GOLD, width=2)
    d.text((W-260, 148), "☀  맑음 22°C", font=font(28), fill=GOLD_L, embedded_color=True)

    # 사진 영역 (큰 카드)
    card(d, 60, 240, W-60, 860)
    # 사진 모의 (따뜻한 그라데이션 + 풍경)
    photo = d.rectangle  # 그냥 컬러 블록으로
    # 하늘
    for y in range(258, 560):
        t = (y - 258) / (560 - 258)
        r_ = int(135 + 40*t); g_ = int(180 + 20*t); b_ = int(220 - 30*t)
        d.line([(78, y), (W-78, y)], fill=(r_, g_, b_))
    # 땅
    for y in range(560, 840):
        t = (y - 560) / (840 - 560)
        r_ = int(80 + 40*t); g_ = int(120 + 20*t); b_ = int(60 + 10*t)
        d.line([(78, y), (W-78, y)], fill=(r_, g_, b_))
    # 태양
    d.ellipse([W//2-50, 290, W//2+50, 390], fill=(255, 240, 140))
    # 나무 실루엣들
    for tx in [150, 280, 700, 820, 920]:
        th = random.randint(120, 200)
        d.rectangle([tx-12, 560-th, tx+12, 620], fill=(40, 60, 30))
        d.ellipse([tx-50, 560-th-80, tx+50, 560-th+40], fill=(50, 90, 40))
    # 날짜 오버레이
    d.rectangle([78, 790, W-78, 840], fill=(0, 0, 0, 120))
    rounded_rect(d, 78, 790, 350, 840, r=0, fill=(0, 0, 0))
    d.text((100, 800), "2026.05.23", font=font(30), fill=(255, 240, 200))

    # 메모 카드
    card(d, 60, 880, W-60, 1120)
    d.text((100, 910), "오늘의 메모", font=font(30), fill=TEXT_SEC)
    d.line([(100, 950), (W-100, 950)], fill=DIVIDER, width=2)
    memo_lines = [
        "오늘은 정말 좋은 날이었다.",
        "공원을 산책하며 봄의 마지막을",
        "느꼈다. 하늘이 너무 맑았다. ☀",
    ]
    for i, line in enumerate(memo_lines):
        d.text((100, 970 + i*52), line, font=font(34), fill=TEXT_PRI, embedded_color=True)
    # 글자 수
    d.text((W-200, 1078), "42/200", font=font(26), fill=GOLD_L)

    # 저장 버튼
    rounded_rect(d, 60, 1160, W-60, 1290, r=36, fill=GOLD)
    d.text((0, 1193), "저  장", font=font(50, bold=True), fill=(255,245,230),
           anchor=None)
    # 텍스트 중앙 정렬
    f_btn = font(50, bold=True)
    bbox = d.textbbox((0,0), "저  장", font=f_btn)
    tw = bbox[2] - bbox[0]
    d.text(((W - tw)//2, 1193), "저  장", font=f_btn, fill=(255,245,230))

    # 하단 네비게이션
    _draw_bottom_nav(d, 0)

    img.save(f"{OUT}/01_today.png", "PNG")
    print("Done: 01_today.png")

# ═══════════════════════════════════════════════════════════════
# 스크린샷 2: 타임라인 (월별 그리드)
# ═══════════════════════════════════════════════════════════════
def make_timeline():
    img, d = new_phone()
    draw_appbar(d, "타임라인", "2026년 5월")

    # 연도 선택 탭
    for i, yr in enumerate(["2024", "2025", "2026"]):
        bx = 60 + i*200
        active = (yr == "2026")
        rounded_rect(d, bx, 228, bx+180, 290, r=30,
                      fill=GOLD if active else (240,232,222))
        col = (255,245,230) if active else TEXT_SEC
        f_yr = font(30, bold=active)
        bbox = d.textbbox((0,0), yr, font=f_yr)
        tw = bbox[2]-bbox[0]
        d.text((bx + (180-tw)//2, 244), yr, font=f_yr, fill=col)

    # 월 그리드 (7열 × 5행 = 35칸, 한달 달력)
    GX = 60    # 그리드 시작 X
    GY = 320   # 그리드 시작 Y
    CELL = 138 # 셀 크기
    GAP = 10

    # 요일 헤더
    days = ["일","월","화","수","목","금","토"]
    for i, d_name in enumerate(days):
        cx = GX + i * (CELL + GAP) + CELL//2
        col = (220,80,60) if i==0 else (60,120,220) if i==6 else TEXT_SEC
        f_d = font(28)
        bbox = d.textbbox((0,0), d_name, font=f_d)
        tw = bbox[2]-bbox[0]
        d.text((cx-tw//2, GY), d_name, font=f_d, fill=col)

    GY += 50

    # 사진이 있는 날 (랜덤 색상으로 표현)
    photo_days = {3,5,6,7,9,12,14,16,17,19,20,22,23,26,28}
    warm_colors = [
        (220,170,120),(200,150,100),(180,130,80),(240,190,140),
        (160,110,70),(210,160,110),(230,180,130),(190,140,90),
    ]
    color_idx = 0

    start_dow = 4  # 2026-05-01은 금요일(4)
    for day in range(1, 32):
        dow = (start_dow + day - 1) % 7
        week = (start_dow + day - 1) // 7
        cx = GX + dow * (CELL + GAP)
        cy = GY + week * (CELL + GAP)

        if cy > 1400: break

        if day in photo_days:
            # 사진 있는 날 — 컬러 블록
            c = warm_colors[color_idx % len(warm_colors)]
            color_idx += 1
            rounded_rect(d, cx, cy, cx+CELL, cy+CELL, r=14, fill=c)
            # 미니 풍경
            # 하늘
            d.rectangle([cx+2, cy+2, cx+CELL-2, cy+CELL//2], fill=(
                min(255,c[0]+30), min(255,c[1]+20), min(255,c[2]+40)))
            # 태양
            d.ellipse([cx+10,cy+6,cx+28,cy+24], fill=(255,240,120))
            # 날짜
            col_d = (80,50,30) if dow not in (0,6) else (80,50,30)
            d.text((cx+6, cy+CELL-38), str(day), font=font(26, bold=True), fill=(50,30,15))
            # 오늘 표시
            if day == 23:
                d.ellipse([cx+CELL-30, cy+4, cx+CELL-4, cy+30],
                           fill=GOLD)
                d.text((cx+CELL-26, cy+6), "오", font=font(18, bold=True), fill=(255,245,230))
        else:
            # 빈 날
            rounded_rect(d, cx, cy, cx+CELL, cy+CELL, r=14,
                          fill=(240,232,222), outline=DIVIDER, width=1)
            col_d = (220,80,60) if dow==0 else (60,120,220) if dow==6 else (200,185,170)
            d.text((cx+8, cy+8), str(day), font=font(26), fill=col_d)

    # 연속 기록 배지
    card(d, 60, 1580, W-60, 1720)
    d.text((100, 1600), "🔥", font=emoji_font(48), fill=GOLD, embedded_color=True)
    d.text((180, 1603), "연속 기록 23일째!", font=font(36, bold=True), fill=TEXT_PRI)
    d.text((180, 1652), "30일 뱃지까지 7일 남았어요", font=font(28), fill=TEXT_SEC)

    _draw_bottom_nav(d, 1)
    img.save(f"{OUT}/02_timeline.png", "PNG")
    print("Done: 02_timeline.png")

# ═══════════════════════════════════════════════════════════════
# 스크린샷 3: 이날의 기억 (n년 전 오늘)
# ═══════════════════════════════════════════════════════════════
def make_memory():
    img, d = new_phone()
    draw_appbar(d, "이날의 기억", "n년 전 오늘")

    years_data = [
        ("2025년 오늘", "1년 전", (200,160,110), "공원에서 커피 한 잔. 날씨 최고."),
        ("2024년 오늘", "2년 전", (160,120,80),  "제주도 여행 마지막 날. 또 오고 싶다."),
        ("2023년 오늘", "3년 전", (130,100,65),  "첫 출근 날. 설레고 긴장됐다."),
    ]

    y_off = 240
    for title, badge, photo_color, memo in years_data:
        card(d, 60, y_off, W-60, y_off+420)

        # 사진 영역
        r_c, g_c, b_c = photo_color
        for py in range(y_off+20, y_off+280):
            t = (py - (y_off+20)) / 260
            d.line([(80, py), (W-80, py)],
                   fill=(int(r_c*(1-t*0.3)), int(g_c*(1-t*0.3)), int(b_c*(1-t*0.3))))
        # 간단한 풍경 실루엣
        d.ellipse([W//2-40, y_off+40, W//2+40, y_off+120], fill=(255,240,140))
        for tx in [140,300,720,860]:
            h_t = 80 + hash(str(tx+y_off)) % 60
            d.rectangle([tx-8, y_off+280-h_t, tx+8, y_off+285], fill=(40,55,30))
            d.ellipse([tx-35, y_off+280-h_t-50, tx+35, y_off+280-h_t+20], fill=(50,80,40))

        # 연도 배지
        rounded_rect(d, 90, y_off+30, 90+len(badge)*22+40, y_off+78,
                      r=24, fill=GOLD)
        d.text((110, y_off+38), badge, font=font(32, bold=True), fill=(255,245,230))

        # 날짜
        d.text((90, y_off+295), title, font=font(30, bold=True), fill=TEXT_PRI)
        # 메모
        d.text((90, y_off+340), memo, font=font(28), fill=TEXT_SEC)
        # 구분선
        d.line([(90, y_off+390), (W-90, y_off+390)], fill=DIVIDER)

        y_off += 450

    _draw_bottom_nav(d, 2)
    img.save(f"{OUT}/03_memory.png", "PNG")
    print("Done: 03_memory.png")

# ═══════════════════════════════════════════════════════════════
# 스크린샷 4: 설정 화면
# ═══════════════════════════════════════════════════════════════
def make_settings():
    img, d = new_phone()
    draw_appbar(d, "설정")

    settings_items = [
        ("💎", "평생 이용권", "구독 없음 · 광고 제거", True, GOLD),
        ("🔔", "매일 알림", "오후 9:00", False, None),
        ("📤", "내보내기", "ZIP · PDF · 연도 회고", False, None),
        ("🗺",  "지도 보기", "GPS 기록 지도", False, None),
        ("🔒", "생체 잠금", "지문 / 얼굴 인식", False, None),
        ("🏆", "달성 뱃지", "23일 연속 기록 중", False, None),
    ]

    y_off = 240
    for icon, title, subtitle, highlight, hl_color in settings_items:
        bg_c = (255, 248, 240) if highlight else SURFACE
        card(d, 60, y_off, W-60, y_off+140)
        if highlight:
            d.rounded_rectangle([60, y_off, W-60, y_off+140], radius=28, fill=bg_c)
            d.rounded_rectangle([60, y_off, W-60, y_off+140], radius=28,
                                  outline=GOLD, width=3, fill=bg_c)

        # 아이콘
        d.text((100, y_off+34), icon, font=emoji_font(52), fill=GOLD, embedded_color=True)
        # 제목
        f_t = font(36, bold=highlight)
        d.text((200, y_off+28), title, font=f_t,
               fill=GOLD_D if highlight else TEXT_PRI)
        # 부제
        d.text((200, y_off+76), subtitle, font=font(26), fill=TEXT_SEC)
        # 화살표 또는 토글
        if highlight:
            rounded_rect(d, W-220, y_off+44, W-80, y_off+96, r=26, fill=GOLD)
            d.text((W-200, y_off+52), "소장 중", font=font(26, bold=True), fill=(255,245,230))
        else:
            d.text((W-100, y_off+48), "›", font=font(60), fill=GOLD_L)

        y_off += 160

    # 버전
    d.text((0, y_off+30), "하루 한 장 v1.0.0", font=font(28), fill=GOLD_L,
           anchor=None)
    f_ver = font(28)
    bbox = d.textbbox((0,0), "하루 한 장 v1.0.0", font=f_ver)
    tw = bbox[2]-bbox[0]
    d.text(((W-tw)//2, y_off+30), "하루 한 장 v1.0.0", font=f_ver, fill=GOLD_L)

    _draw_bottom_nav(d, 3)
    img.save(f"{OUT}/04_settings.png", "PNG")
    print("Done: 04_settings.png")

# ── 하단 내비게이션 ───────────────────────────────────────────
def _draw_bottom_nav(d, active_idx):
    d.rectangle([0, H-160, W, H], fill=BG_DARK)
    nav_items = [("📷","오늘"), ("📅","타임라인"), ("✨","기억"), ("⚙","설정")]
    for i, (icon, label) in enumerate(nav_items):
        nx = W//4 * i + W//8
        active = (i == active_idx)
        c_icon = (255, 240, 220) if active else (120, 90, 70)
        c_label = GOLD_L if active else (100, 75, 55)
        d.text((nx-20, H-148), icon, font=emoji_font(38), fill=c_icon, embedded_color=True)
        f_nav = font(24, bold=active)
        bbox = d.textbbox((0,0), label, font=f_nav)
        tw = bbox[2]-bbox[0]
        d.text((nx-tw//2, H-92), label, font=f_nav, fill=c_label)
        if active:
            d.ellipse([nx-6, H-40, nx+6, H-28], fill=GOLD)

# ═════════════════════════════════════════════════════════════
random.seed(42)
make_today()
make_timeline()
make_memory()
make_settings()
print("All screenshots saved to", OUT)
