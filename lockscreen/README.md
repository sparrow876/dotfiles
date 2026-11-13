# Lock screen + login screen (qylock)

**Theme: qylock's "winter"** on both the lock screen and the SDDM login screen.
`themes/pastel-pink` (this repo's own, MIT, qylock theme format) was tried on
2026-11-13 and dropped; it stays available: `scripts/lock.sh pastel-pink`, and
`system/root-steps/6-login-theme.sh` would install it for SDDM. Its `bg.jpg`
(wallhaven 3z86od) is not in git; without it a pink gradient is shown.

The lock screen itself (session lock + PAM) and the winter theme come from
[qylock](https://github.com/Darkkal44/qylock) by Darkkal44 (**GPL-3.0**).

- `install.sh` clones qylock to `~/.local/src/qylock` at a pinned commit (see
  `CLONES` in `install.sh`). Nothing from qylock is copied into this repo.
- You install it by running qylock's own `quickshell.sh` (lock screen) and
  `sddm.sh` (login screen), then `system/root-steps/4-login.sh`
  (ROOT-STEPS.md §10 has what each script does).
- The lock command is `scripts/lock.sh` (SUPER + L, the power menu, hypridle
  and before suspend), which starts qylock's
  `~/.local/share/quickshell-lockscreen/lock.sh` unless already locked.
- **Fixes:** `patches/qylock-lockscreen.patch` (GPL-3.0, derived from qylock;
  this repo's MIT license doesn't cover it) fixes the lock screen's login
  code: Enter on an empty password box used to start a password check that
  never finished, after which no password worked (2026-11-13). It also shows
  PAM's reason on failure (e.g. faillock's 10-minute lockout after 3 wrong
  passwords) instead of only "ACCESS DENIED". Applied by `apply-patches.sh`
  (also run by `install.sh`): patches the clone, then refreshes the installed
  lock screen's copy. Re-run it after re-running qylock's `quickshell.sh`;
  `apply-patches.sh --revert` undoes it (do that before changing the pinned
  commit). SDDM's login screen is not affected by the bug and not patched.
- Apart from that the theme is used unmodified.

Crash recovery and a broken login screen: README.md → Recovery.
