"""Image of an equation -> LaTeX code, with pix2tex (LaTeX-OCR).

Runs inside the private venv made by setup.sh (python = that venv's python):
    python -I latex_ocr.py --ask IMAGE.png   via the background server (fast)
    python -I latex_ocr.py --warm            start the server if it isn't running
    python -I latex_ocr.py --stop            stop the server
    python -I latex_ocr.py IMAGE.png         one-off, no server (~9 s)
    python -I latex_ocr.py --selftest        one-off on a drawn x^2+y^2=r^2
Prints only the LaTeX on stdout; messages go to stderr.
Used by scripts/latex-ocr.sh (ALT + SHIFT + O).

Background server: loading PyTorch + the model takes ~8 s, reading one
equation ~1 s. The server loads once, answers on a Unix socket in
$XDG_RUNTIME_DIR (only you can reach it) and exits after LATEX_OCR_IDLE
seconds without a request (default 1200 = 20 min) to give the ~1 GB back.
Its log: $XDG_RUNTIME_DIR/latex-ocr.log.
"""
import contextlib
import json
import os
import socket
import subprocess
import sys
import time

RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/latex-ocr-{os.getuid()}"
SOCK = os.path.join(RUNTIME, "latex-ocr.sock")
LOCK = os.path.join(RUNTIME, "latex-ocr.lock")
LOG = os.path.join(RUNTIME, "latex-ocr.log")
IDLE = int(os.environ.get("LATEX_OCR_IDLE", "1200"))


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


def load_model():
    # pix2tex prints progress to stdout: keep stdout for the result only
    with contextlib.redirect_stdout(sys.stderr):
        import pix2tex.cli as cli

        cli.clipboard.copy = lambda *_: None  # it copies every result itself; we do that
        return cli.LatexOCR()


def recognise(model, img):
    img = clean(img)
    if os.environ.get("LATEX_OCR_DEBUG"):
        img.save(os.environ["LATEX_OCR_DEBUG"])  # what the model sees
    with contextlib.redirect_stdout(sys.stderr):
        return model(img)


# --- background server --------------------------------------------------------
def serve():
    import fcntl

    from PIL import Image

    os.makedirs(RUNTIME, mode=0o700, exist_ok=True)
    lock = open(LOCK, "w")
    try:  # only one server; a second one started at the same time just exits
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return
    model = load_model()
    with contextlib.suppress(FileNotFoundError):
        os.unlink(SOCK)  # left over from a crash
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    old = os.umask(0o177)  # socket: owner only
    srv.bind(SOCK)
    os.umask(old)
    srv.listen(4)
    srv.settimeout(IDLE)
    print(f"ready, exits after {IDLE} s idle", file=sys.stderr, flush=True)
    try:
        while True:
            try:
                conn, _ = srv.accept()
            except socket.timeout:
                break
            with conn:
                conn.settimeout(10)
                try:
                    req = conn.makefile().readline().strip()
                    if req == "STOP":
                        conn.sendall(b'{"ok": true}\n')
                        break
                    t = time.monotonic()
                    reply = {"latex": recognise(model, Image.open(req).convert("RGB"))}
                    print(f"read {req} in {time.monotonic() - t:.2f} s", file=sys.stderr, flush=True)
                except Exception as e:  # a bad image must not kill the server
                    reply = {"error": f"{type(e).__name__}: {e}"}
                with contextlib.suppress(OSError):
                    conn.sendall((json.dumps(reply) + "\n").encode())
    finally:
        srv.close()
        with contextlib.suppress(FileNotFoundError):
            os.unlink(SOCK)


def request(line, timeout):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect(SOCK)
    with s:
        s.sendall((line + "\n").encode())
        return json.loads(s.makefile().readline())


def start_server():
    """Start the server in the background (it outlives this process)."""
    with open(LOG, "a") as log:
        return subprocess.Popen(
            [sys.executable, "-I", os.path.abspath(__file__), "--serve"],
            stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True,
        )


def running():
    """True if a server is listening, or one is still loading the model."""
    import fcntl

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        try:
            s.connect(SOCK)
            return True
        except OSError:
            pass
    try:
        with open(LOCK, "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)  # free = nobody loading
        return False
    except BlockingIOError:
        return True


def ask(path):
    path = os.path.abspath(path)
    try:
        reply = request(path, 60)
    except (FileNotFoundError, ConnectionRefusedError):
        # not running (or still loading): start one, wait until it listens
        proc = start_server()
        deadline = time.monotonic() + 120
        while True:
            time.sleep(0.2)
            try:
                reply = request(path, 60)
                break
            except (FileNotFoundError, ConnectionRefusedError):
                if time.monotonic() > deadline:
                    sys.exit("the LaTeX OCR server didn't start in 2 minutes; see " + LOG)
                # ours exiting with 0 = another server was already loading
                # (keep waiting for that one); non-zero = it crashed
                if proc.poll() not in (None, 0):
                    sys.exit("the LaTeX OCR server failed; see " + LOG)
    if "error" in reply:
        sys.exit(reply["error"])
    print(reply["latex"])


def main():
    args = sys.argv[1:]
    if args == ["--serve"]:
        serve()
    elif args == ["--warm"]:
        if not running():
            start_server()
    elif args == ["--stop"]:
        with contextlib.suppress(OSError):
            request("STOP", 5)
    elif len(args) == 2 and args[0] == "--ask":
        ask(args[1])
    elif args == ["--selftest"]:
        print(recognise(load_model(), test_image()))
        print("self-test OK (expected something like x^{2}+y^{2}=r^{2})", file=sys.stderr)
    elif len(args) == 1 and not args[0].startswith("-"):
        from PIL import Image

        print(recognise(load_model(), Image.open(args[0]).convert("RGB")))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
