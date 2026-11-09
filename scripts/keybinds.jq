# Turn `hyprctl binds -j` into grouped, readable keybinds. Used by BOTH the
# cheat sheet (ALT + /, quickshell services/Keybinds.qml) and
# scripts/keybinds-to-md.sh (README table), so they always agree.
# Output: [{ category, items: [{ action, keys: ["ALT + Enter", ...] }] }]
# Binds without a "Category: Action" description are skipped.

def modnames:
  [ [64, "SUPER"], [8, "ALT"], [4, "CTRL"], [1, "SHIFT"] ] as $m
  | . as $mask | [ $m[] | select(($mask / .[0] | floor) % 2 == 1) | .[1] ];

def prettykey:
  {
    "grave": "`", "slash": "/", "Return": "Enter", "Escape": "Esc",
    "left": "←", "right": "→", "up": "↑", "down": "↓", "Tab": "Tab", "space": "Space",
    "mouse:272": "Left-drag", "mouse:273": "Right-drag",
    "mouse_down": "Scroll down", "mouse_up": "Scroll up",
    "XF86AudioRaiseVolume": "Volume Up", "XF86AudioLowerVolume": "Volume Down",
    "XF86AudioMute": "Mute key", "XF86AudioMicMute": "Mic Mute key",
    "XF86AudioPlay": "Play key", "XF86AudioPause": "Pause key",
    "XF86AudioNext": "Next key", "XF86AudioPrev": "Previous key",
    "XF86MonBrightnessUp": "Brightness Up", "XF86MonBrightnessDown": "Brightness Down"
  }[.] // (if length == 1 then ascii_upcase else . end);

[ .[] | select(.description != null and (.description | test("^[^:]+: "))) ]
# one row per bind: category, action, readable combo
| map({
    category: (.description | sub(":.*$"; "")),
    action:   (.description | sub("^[^:]+: "; "")),
    mods:     (.modmask | modnames),
    key:      (.key | prettykey)
  } | .combo = ((.mods + [.key]) | join(" + ")))
# merge binds with the same category+action (e.g. H and ← for "Focus left"),
# keeping the order they were defined in
| reduce .[] as $b ([];
    (map(.category + "\u0000" + .action) | index($b.category + "\u0000" + $b.action)) as $i
    | if $i == null then . + [$b + {keys: [$b.combo]}]
      else .[$i].keys += (if (.[$i].keys | index($b.combo)) then [] else [$b.combo] end) end)
# collapse numbered actions ("Go to workspace 1".."6") into one row
| reduce .[] as $b ([];
    ([ $b.action | capture("^(?<p>.+) (?<n>[0-9])$") ] | .[0]) as $c   # null if no number
    | if $c == null then . + [$b]
      else (map(.category + "\u0000" + (.prefix // "")) | index($b.category + "\u0000" + $c.p)) as $i
      | if $i == null then . + [$b + {prefix: $c.p, nums: [$c.n], base: ($b.mods | join(" + "))}]
        else .[$i].nums += [$c.n] end
      end)
| map(if .nums and (.nums | length) > 1
      then .action = "\(.prefix) \(.nums | min)–\(.nums | max)"
         | .keys = ["\(if .base == "" then "" else .base + " + " end)\(.nums | min)…\(.nums | max)"]
      else . end)
# group by category, in first-seen order
| reduce .[] as $b ([];
    (map(.category) | index($b.category)) as $i
    | if $i == null then . + [{category: $b.category, items: [{action: $b.action, keys: $b.keys}]}]
      else .[$i].items += [{action: $b.action, keys: $b.keys}] end)
