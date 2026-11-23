#!/usr/bin/env bash
# CPU package temperature for the stats panel, averaged over time.
# The package sensor sits in the die next to the cores and follows their power
# within milliseconds: a short burst of work takes it from ~40 to 70-85 °C and
# back within a quarter of a second (measured 2026-11-23), while the cooler
# barely changes. The hwmon value is also a snapshot cached for up to 1 s, so
# one reading per panel refresh jumped between ~40 and ~80 °C at random.
# This reads the sensor every 100 ms and prints "<mean> <max>" in °C for each
# 1.5 s window (the first after 0.5 s, so the panel fills in quickly). The loop
# uses only bash builtins, so the sampling itself doesn't wake the CPU into a
# burst. Run by services/SystemStats.qml only while the panel is open; it ends
# when the panel closes, or when nobody reads it any more (the write fails).
set -u

src=""
for z in /sys/class/thermal/thermal_zone*; do       # read live on every access
  read -r t < "$z/type" 2>/dev/null || continue
  [[ $t == x86_pkg_temp ]] && { src=$z/temp; break; }
done
if [[ -z $src ]]; then                               # fallback: coretemp (cached 1 s)
  for h in /sys/class/hwmon/hwmon*; do
    read -r n < "$h/name" 2>/dev/null || continue
    [[ $n == coretemp ]] && { src=$h/temp1_input; break; }
  done
fi
[[ -n $src ]] || exit 0

exec {tick}<> <(:)   # a pipe nobody writes to: `read -t` on it sleeps without starting a process
sum=0 n=0 max=0 want=5
while :; do
  read -r t < "$src" || exit 0
  (( sum += t, n += 1 ))
  (( t > max )) && max=$t
  if (( n >= want )); then
    mean=$(( (sum + n / 2) / n ))                    # millidegrees, rounded
    printf '%d.%d %d\n' $(( mean / 1000 )) $(( mean % 1000 / 100 )) $(( (max + 500) / 1000 )) || exit 0
    sum=0 n=0 max=0 want=15
  fi
  read -r -t 0.1 -u "$tick" _
done
