"""Image of an equation -> LaTeX code, with pix2tex (LaTeX-OCR).

Runs inside the private venv made by setup.sh:
    ~/.local/share/latex-ocr/venv/bin/python -I latex_ocr.py IMAGE.png
    ... latex_ocr.py --selftest
Prints only the LaTeX on stdout; pix2tex's own messages go to stderr.
Used by scripts/latex-ocr.sh (ALT + SHIFT + O).
"""
import contextlib
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


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: latex_ocr.py IMAGE | --selftest")
    from PIL import Image

    img = test_image() if sys.argv[1] == "--selftest" else Image.open(sys.argv[1])

    # pix2tex prints progress to stdout: keep stdout for the result only
    with contextlib.redirect_stdout(sys.stderr):
        import pix2tex.cli as cli

        cli.clipboard.copy = lambda *_: None  # it copies every result itself; we do that
        latex = cli.LatexOCR()(img.convert("RGB"))
    print(latex)
    if sys.argv[1] == "--selftest":
        print("self-test OK (expected something like x^{2}+y^{2}=r^{2})", file=sys.stderr)


if __name__ == "__main__":
    main()
