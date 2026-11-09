# Themes

The whole desktop's colors come from one palette file. Switch with **ALT + T**
(picker with swatches) or from a terminal:

```sh
theme/apply.sh                     # list themes, * = active
theme/apply.sh catppuccin-mocha    # switch + reload running apps
```

| File | What it is |
|------|------------|
| `palettes/<name>.toml` | One theme: `[meta]` name, `[colors]` |
| `style.toml` | Fonts, text sizes, rounding, gaps (shared by every theme) |
| `current` | Name of the active palette |
| `templates/**.tmpl` | Each app's color file with `{{placeholders}}` |
| `render.sh` | Fills the templates from style + active palette |
| `apply.sh` | Sets `current`, renders, reloads Hyprland/kitty/Quickshell/bat/GTK |

Included: **Blue Ice** (the original) and **Catppuccin Mocha / Macchiato /
Frappé**, using Catppuccin's official palette. All themes are dark (light
themes were removed on purpose: the icon theme, GTK/Qt preference and
contrast are only set up for dark).

Not themed by design: Neovim, Nautilus and zathura (Nord), the lock/login
screen (qylock theme).

## Adding a theme

Copy a palette and change the colors; every theme uses the same role names:

| Role | Used for |
|------|----------|
| `base` | deepest background (dim overlays, text on accent pills) |
| `surface` | bar, panels, popups, rofi, kitty background |
| `overlay` | cards, hover, inactive borders |
| `blue` | secondary / dim accent (terminal "bright black") |
| `lightblue` | primary accent: active workspace, selection, borders |
| `ice` | highlights, graphs, second border color |
| `text` / `muted` | main / secondary text |
| `warn` / `critical` | warnings (battery < 20 %, temps) / errors (recording dot) |
| `green` `magenta` `cyan` | terminal ANSI colors |

Then `theme/apply.sh <new-name>`. Generated files are committed so a fresh
clone works without rendering; commit after switching if you want the new
theme to be the repo default.
