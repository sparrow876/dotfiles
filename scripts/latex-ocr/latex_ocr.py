"""Image of an equation -> LaTeX code, with pix2tex (LaTeX-OCR).

Runs inside the private venv made by setup.sh:
    ~/.local/share/latex-ocr/venv/bin/python -I latex_ocr.py IMAGE.png
    ... latex_ocr.py --selftest
Prints only the LaTeX on stdout; pix2tex's own messages go to stderr.
Used by scripts/latex-ocr.sh (ALT + SHIFT + O).
"""
import contextlib
import os
import sys


def test_image():
    # "x^2 + y^2 = r^2" drawn large on white, enough to exercise the model
    from PIL import Image, ImageDraw, ImageFont

    img = Image.new("RGB", (420, 110), "white")
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("DejaVuSerif-Italic.ttf", 44)
        small = ImageFont.truetype("DejaVuSerif.ttf", 26)
    except OSError:
        font = small = ImageFont.load_default()
    x = 20
    for text, f, dy in [("x", font, 30), ("2", small, 14), (" + ", font, 30), ("y", font, 30),
                        ("2", small, 14), (" = ", font, 30), ("r", font, 30), ("2", small, 14)]:
        draw.text((x, dy), text, fill="black", font=f)
        x += draw.textlength(text, font=f)
    return img


def clean(img):
    """Return just the equation, dark text on white, tightly cropped.

    pix2tex expects a rendered formula on a plain light background and decides
    what "text" is by brightness alone. A screen selection often has more in
    it: a dark viewer around a light picture, a tinted box with an outline,
    dark mode. Then it reads the whole box as one glyph and outputs garbage
    (endless \\qquad). So: split pixels into two classes (Otsu), try both as
    "ink", drop blobs that touch the selection edge or look like a frame, and
    keep the reading with the most glyph-sized blobs (real text = many small
    pieces). The kept ink keeps its anti-aliasing (grey levels), like a render.
    """
    import cv2
    import numpy as np
    from PIL import Image

    gray = np.array(img.convert("L"))
    H, W = gray.shape
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    best = None
    for ink_is_dark in (True, False):
        ink = (binary == 0) if ink_is_dark else (binary == 255)
        n, labels, stats, _ = cv2.connectedComponentsWithStats(ink.astype(np.uint8), connectivity=8)
        keep = []
        for i in range(1, n):
            x, y, w, h, area = stats[i]
            touches_edge = x == 0 or y == 0 or x + w == W or y + h == H
            frame_like = w > 0.8 * W and h > 0.6 * H  # an outline/box around everything
            if area < 3 or touches_edge or frame_like:
                continue
            keep.append(i)
        if keep and (best is None or len(keep) > len(best[1])):
            best = (ink_is_dark, keep, labels, stats)
    if best is None:
        return img  # nothing recognisable: let pix2tex try the original

    # The blobs only decide where the equation is and which way round it is.
    # The model gets the original pixels of that area (all dots, thin strokes
    # and anti-aliasing intact), dark-on-light, background levelled to white.
    ink_is_dark, keep, _, stats = best
    x0 = min(stats[i][0] for i in keep); y0 = min(stats[i][1] for i in keep)
    x1 = max(stats[i][0] + stats[i][2] for i in keep); y1 = max(stats[i][1] + stats[i][3] for i in keep)
    m = 2  # a hair of margin for anti-aliased edges; frames sit further out
    g = gray[max(0, y0 - m):min(H, y1 + m), max(0, x0 - m):min(W, x1 + m)].astype(np.float32)
    if not ink_is_dark:
        g = 255 - g
    lo, bg = np.percentile(g, 1), np.median(g)  # darkest ink, background
    g = np.clip((g - lo) / max(bg - lo, 1) * 255, 0, 255).astype(np.uint8)
    g = cv2.copyMakeBorder(g, 8, 8, 8, 8, cv2.BORDER_CONSTANT, value=255)
    return Image.fromarray(g).convert("RGB")


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: latex_ocr.py IMAGE | --selftest")
    from PIL import Image

    img = test_image() if sys.argv[1] == "--selftest" else Image.open(sys.argv[1])

    # pix2tex prints progress to stdout: keep stdout for the result only
    with contextlib.redirect_stdout(sys.stderr):
        import pix2tex.cli as cli

        cli.clipboard.copy = lambda *_: None  # it copies every result itself; we do that
        img = clean(img)
        if os.environ.get("LATEX_OCR_DEBUG"):
            img.save(os.environ["LATEX_OCR_DEBUG"])  # what the model sees
        latex = cli.LatexOCR()(img)
    print(latex)
    if sys.argv[1] == "--selftest":
        print("self-test OK (expected something like x^{2}+y^{2}=r^{2})", file=sys.stderr)


if __name__ == "__main__":
    main()
