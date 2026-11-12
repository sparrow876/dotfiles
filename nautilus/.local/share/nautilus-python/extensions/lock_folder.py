# Nautilus right-click:
#   on a folder        → "Lock with Password…"  (folder becomes NAME.locked)
#   on a .locked file  → "Unlock…"              (asks the password, folder is back)
# The dialogs and the work are in ~/dotfiles/scripts/lockdir-gui.sh (zenity +
# lockdir.sh); this file only adds the menu entries.
# Restart Nautilus after changes: nautilus -q
import os
import subprocess

from gi.repository import GObject, Nautilus

# This file is a stow symlink into the repo: <repo>/nautilus/.local/share/
# nautilus-python/extensions/lock_folder.py → the repo is 6 levels up.
_REPO = os.path.realpath(__file__)
for _ in range(6):
    _REPO = os.path.dirname(_REPO)
SCRIPT = os.path.join(_REPO, "scripts", "lockdir-gui.sh")


def _run(mode, info):
    path = info.get_location().get_path()
    if path:
        subprocess.Popen([SCRIPT, mode, path], start_new_session=True)


class LockFolder(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, files):
        # One item at a time, local files only
        if len(files) != 1 or not files[0].get_location().get_path():
            return []
        info = files[0]
        if info.is_directory():
            item = Nautilus.MenuItem(
                name="LockFolder::lock",
                label="Lock with Password…",
                tip="Turn this folder into one password-protected file",
            )
            item.connect("activate", lambda _item: _run("lock", info))
            return [item]
        if info.get_name().endswith(".locked"):
            item = Nautilus.MenuItem(
                name="LockFolder::unlock",
                label="Unlock…",
                tip="Enter the password to get the folder back",
            )
            item.connect("activate", lambda _item: _run("unlock", info))
            return [item]
        return []
