#!/usr/bin/env bash
# One-time setup for LaTeX OCR (ALT + SHIFT + O): a private Python environment
# with pix2tex (github.com/lukas-blecher/LaTeX-OCR, MIT) and CPU-only PyTorch.
# You run this yourself (it installs third-party code); no root needed.
#
# What it does:
#   1. creates ~/.local/share/latex-ocr/venv (a Python venv; nothing else on
#      the system changes)
#   2. installs the packages in requirements.txt with pip --require-hashes:
#      each one must match its pinned SHA-256, wheels only (nothing is
#      compiled). Downloads ~250 MB from pypi.org and download.pytorch.org
#      (~1.3 GB on disk, mostly PyTorch + SciPy)
#   3. downloads the two model files (~100 MB) from the pix2tex GitHub release
#      v0.0.1 and checks their SHA-256 (pix2tex would otherwise download them
#      unchecked on first use)
#
# Re-run it any time: it starts from a fresh venv. Undo everything:
#   rm -rf ~/.local/share/latex-ocr
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${XDG_DATA_HOME:-$HOME/.local/share}/latex-ocr"
venv="$root/venv"
release="https://github.com/lukas-blecher/LaTeX-OCR/releases/download/v0.0.1"
declare -A model_sha=(
  [weights.pth]=a63d9141c53d266cb682fb5a8bd83bd5cbe283145e0e78ebdc0f895195a1dfaa
  [image_resizer.pth]=1c3820659985ad142b526490bb25c23d977176ac2073591b3bddada692718458
)

echo "==> Creating $venv"
rm -rf -- "$venv"
mkdir -p -- "$root"
python3 -m venv "$venv"

echo "==> Installing pinned packages (hash-checked, wheels only)"
"$venv/bin/pip" install --disable-pip-version-check --no-deps --only-binary=:all: \
  --require-hashes -r "$here/requirements.txt" \
  --index-url https://download.pytorch.org/whl/cpu \
  --extra-index-url https://pypi.org/simple

ckpt="$("$venv/bin/python" -I -c 'import importlib.util, os; s = importlib.util.find_spec("pix2tex"); print(os.path.join(os.path.dirname(s.origin), "model", "checkpoints"))')"
echo "==> Downloading the model into $ckpt"
mkdir -p -- "$ckpt"
for f in "${!model_sha[@]}"; do
  tmp="$ckpt/$f.part"
  curl -fL --progress-bar -o "$tmp" "$release/$f"
  if [[ $(sha256sum "$tmp" | cut -d' ' -f1) != "${model_sha[$f]}" ]]; then
    rm -f -- "$tmp"
    echo "!! $f: checksum mismatch, not installed" >&2
    exit 1
  fi
  mv -- "$tmp" "$ckpt/$f"
done

echo "==> Test run"
if "$venv/bin/python" -I "$here/latex_ocr.py" --selftest; then
  echo "Done. Press ALT + SHIFT + O and drag a box around an equation."
else
  echo "!! The test failed; send the output above to Claude." >&2
  exit 1
fi
