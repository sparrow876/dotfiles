# Nautilus right-click → "Copy as Path": puts the full path of the selected
# file(s) on the clipboard (one per line), e.g. /home/you/Documents/notes.pdf.
# Right-click on empty space copies the current folder's path.
# Loaded by nautilus-python (installed with nautilus-open-any-terminal);
# restart Nautilus after changes: nautilus -q
import gi

gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, GObject, Nautilus  # noqa: E402


def _path(info):
    # Real path when there is one (also for Google Drive / USB mounts),
    # otherwise the URI (e.g. a phone over MTP without a local path)
    location = info.get_location()
    return location.get_path() or location.get_uri()


def _copy(paths):
    Gdk.Display.get_default().get_clipboard().set("\n".join(paths))


class CopyAsPath(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, files):
        if not files:
            return []
        item = Nautilus.MenuItem(
            name="CopyAsPath::files",
            label="Copy as Path" if len(files) == 1 else "Copy as Paths",
            tip="Copy the full path to the clipboard",
        )
        item.connect("activate", lambda _item: _copy([_path(f) for f in files]))
        return [item]

    def get_background_items(self, folder):
        item = Nautilus.MenuItem(
            name="CopyAsPath::folder",
            label="Copy Folder Path",
            tip="Copy this folder's full path to the clipboard",
        )
        item.connect("activate", lambda _item: _copy([_path(folder)]))
        return [item]
