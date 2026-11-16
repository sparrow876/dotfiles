# Nautilus right-click:
#   on a folder          → "View All Images"  (that folder + all subfolders)
#   on empty space       → "View All Images"  (the folder you're in)
# Opens qimgv's thumbnail grid via ~/dotfiles/scripts/view-all-images.sh; this
# file only adds the menu entries.
# Restart Nautilus after changes: nautilus -q
import os
import subprocess

from gi.repository import GObject, Nautilus

# This file is a stow symlink into the repo: <repo>/nautilus/.local/share/
# nautilus-python/extensions/view_all_images.py → the repo is 6 levels up.
_REPO = os.path.realpath(__file__)
for _ in range(6):
    _REPO = os.path.dirname(_REPO)
SCRIPT = os.path.join(_REPO, "scripts", "view-all-images.sh")


def _item(name, path):
    item = Nautilus.MenuItem(
        name=name,
        label="View All Images",
        tip="Open every image in this folder and its subfolders in qimgv",
    )
    item.connect(
        "activate",
        lambda _item: subprocess.Popen([SCRIPT, path], start_new_session=True),
    )
    return item


class ViewAllImages(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, files):
        # One local folder at a time
        if len(files) != 1 or not files[0].is_directory():
            return []
        path = files[0].get_location().get_path()
        return [_item("ViewAllImages::folder", path)] if path else []

    def get_background_items(self, folder):
        path = folder.get_location().get_path()
        return [_item("ViewAllImages::here", path)] if path else []
