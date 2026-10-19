"""App Store 用のスクリーンショット（6.9インチ: 1320x2868）を作る。

iPhone で撮った画面を store/raw/ に置き、見出し付きの画像にして store/screenshots/ に書き出す。
見出しは CAPTIONS の順に、raw/ のファイル名の順（01.png, 02.png …）で当てはめる。
使い方: python store/make_screenshots.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 1320, 2868
BG = (14, 14, 18)
ACCENT = (255, 140, 71)
WHITE = (255, 255, 255)
SUB = (150, 150, 160)

# (大見出し, 小見出し)
CAPTIONS = [
    ("音楽を止めずに、ピッ。", "聴いている曲はそのまま。合図の音だけ重ねて鳴らします"),
    ("ロック画面で長押しするだけ", "プリセットを選べば、止めるまでくり返します"),
    ("残り時間はロック画面に", "今の区間と次の区間がひと目で分かります"),
    ("筋トレのレストも、ポモドーロも", "30秒〜60分の区間を5つまで並べられます"),
]

FONT_BOLD = r"C:\Windows\Fonts\YuGothB.ttc"
FONT_REG = r"C:\Windows\Fonts\YuGothM.ttc"


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0], img.size[1]], radius=radius, fill=255)
    out = Image.new("RGBA", img.size)
    out.paste(img, (0, 0), mask)
    return out


def compose(shot: Path, title: str, subtitle: str) -> Image.Image:
    canvas = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(canvas)

    # 見出し
    title_font = ImageFont.truetype(FONT_BOLD, 92)
    sub_font = ImageFont.truetype(FONT_REG, 44)
    d.text((W / 2, 250), title, font=title_font, fill=WHITE, anchor="mm")
    d.text((W / 2, 370), subtitle, font=sub_font, fill=SUB, anchor="mm")
    d.rounded_rectangle([W / 2 - 60, 450, W / 2 + 60, 462], radius=6, fill=ACCENT)

    # 端末の画面（下にはみ出して大きく見せる）
    raw = Image.open(shot).convert("RGB")
    target_w = 1040
    target_h = round(raw.height * target_w / raw.width)
    raw = raw.resize((target_w, target_h), Image.LANCZOS)
    screen = rounded(raw, 90)
    x = (W - target_w) // 2
    y = 560
    frame = 22
    d.rounded_rectangle([x - frame, y - frame, x + target_w + frame, y + target_h + frame], radius=110, fill=(40, 40, 48))
    canvas.paste(screen, (x, y), screen)
    return canvas


def main():
    root = Path(__file__).resolve().parent
    shots = sorted((root / "raw").glob("*.png")) + sorted((root / "raw").glob("*.jpg"))
    out_dir = root / "screenshots"
    out_dir.mkdir(exist_ok=True)
    for i, shot in enumerate(shots):
        title, subtitle = CAPTIONS[i % len(CAPTIONS)]
        path = out_dir / f"{i + 1:02d}.png"
        compose(shot, title, subtitle).save(path)
        print("saved", path)


if __name__ == "__main__":
    main()
