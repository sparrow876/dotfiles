# Lock screen + login screen (qylock)

Both the lock screen and the SDDM login screen use the **"winter"** theme from
[qylock](https://github.com/Darkkal44/qylock) by Darkkal44 (**GPL-3.0**).

- `install.sh` clones qylock to `~/.local/src/qylock` at a pinned commit (see
  `CLONES` in `install.sh`). Nothing from qylock is copied into this repo.
- You install it by running qylock's own `quickshell.sh` (lock screen) and
  `sddm.sh` (login screen), then `system/root-steps/4-login.sh`
  (ROOT-STEPS.md §10 has what each script does).
- The lock command is `scripts/lock.sh` (SUPER + L, the power menu, hypridle
  and before suspend), which starts qylock's
  `~/.local/share/quickshell-lockscreen/lock.sh` unless already locked.
- The theme is used unmodified. If a color patch is ever added to this folder,
  it is derived from qylock and must keep qylock's GPL-3.0 license notice
  (this repo's MIT license doesn't cover it).

Crash recovery and a broken login screen: README.md → Recovery.
