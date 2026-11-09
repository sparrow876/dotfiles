#!/usr/bin/env bash
# One snapshot of system stats as JSON, for the stats panel (ALT + S).
# Run by services/SystemStats.qml every 1.5 s ONLY while the panel is open.
# Counters are cumulative; the panel turns differences into rates.
# Never wakes the RTX 3050: nvidia-smi only runs if the GPU is already awake.
set -u
export LC_ALL=C

json_str() { printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }

host=$(cat /proc/sys/kernel/hostname)
kernel=$(cat /proc/sys/kernel/osrelease)
uptime=$(cut -d' ' -f1 /proc/uptime)
load=$(awk '{printf "[%s,%s,%s]", $1, $2, $3}' /proc/loadavg)

# CPU: [busy, total] jiffies for the whole CPU and for each core
cpu=$(awk '/^cpu/ { busy=$2+$3+$4+$7+$8+$9; total=busy+$5+$6; printf "%s[%d,%d]", (n++ ? "," : ""), busy, total }' /proc/stat)

# Frequency (MHz): average and max over cores
freq=$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null |
       awk '{ s+=$1; if ($1>m) m=$1; n++ } END { if (n) printf "[%d,%d]", s/n/1000, m/1000; else printf "null" }')

# CPU package temperature from the coretemp hwmon (found by name; numbers change)
temp=null
for h in /sys/class/hwmon/hwmon*; do
  if [[ $(cat "$h/name" 2>/dev/null) == coretemp ]]; then
    temp=$(awk '{ printf "%.1f", $1/1000 }' "$h/temp1_input" 2>/dev/null || echo null)
    break
  fi
done

mem=$(awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/ { gsub(":",""); v[$1]=$2 }
           END { printf "{\"total\":%d,\"avail\":%d,\"swapTotal\":%d,\"swapFree\":%d}", v["MemTotal"], v["MemAvailable"], v["SwapTotal"], v["SwapFree"] }' /proc/meminfo)

# Intel iGPU: current / max frequency (MHz)
igpu=null
for gt in /sys/class/drm/card*/gt/gt0; do
  if [[ -r $gt/rps_act_freq_mhz ]]; then
    igpu="{\"cur\":$(cat "$gt/rps_act_freq_mhz"),\"max\":$(cat "$gt/rps_max_freq_mhz")}"
    break
  fi
done

# NVIDIA: only query when it's already awake (querying wakes it up otherwise)
nv=null
for d in /sys/bus/pci/devices/*; do
  [[ $(cat "$d/vendor" 2>/dev/null) == 0x10de && $(cat "$d/class" 2>/dev/null) == 0x03* ]] || continue
  state=$(cat "$d/power/runtime_status" 2>/dev/null || echo unknown)
  if [[ $state == active ]] && command -v nvidia-smi >/dev/null; then
    q=$(nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,clocks.gr \
                   --format=csv,noheader,nounits 2>/dev/null | head -1)
    if [[ -n $q ]]; then
      IFS=',' read -r name util t mu mt pw clk <<<"$q"
      nv="{\"state\":\"active\",\"name\":$(json_str "${name# }"),\"util\":${util// /},\"temp\":${t// /},\"memUsed\":${mu// /},\"memTotal\":${mt// /},\"power\":${pw// /},\"clock\":${clk// /}}"
      nv=${nv//\[N\/A\]/null}
    fi
  fi
  [[ $nv == null ]] && nv="{\"state\":$(json_str "$state")}"
  break
done

# Disks: one entry per real filesystem (btrfs subvolumes collapse into one),
# skipping FUSE (Google Drive), tmpfs and friends
disks=$(findmnt -rn -b -o TARGET,SOURCE,FSTYPE,SIZE,USED -t btrfs,ext4,xfs,vfat,exfat,ntfs3,f2fs |
        awk '{ dev=$2; sub(/\[.*/, "", dev); if (seen[dev]++) next;
               printf "%s{\"mount\":\"%s\",\"dev\":\"%s\",\"fs\":\"%s\",\"size\":%s,\"used\":%s}", (n++ ? "," : ""), $1, dev, $3, $4, $5 }')

# Disk I/O of the disk holding / (sectors read, written)
rootsrc=$(findmnt -rn -o SOURCE / | sed 's/\[.*//')
rootdev=$(lsblk -no PKNAME "$rootsrc" 2>/dev/null | head -1)
diskio=$(awk -v d="$rootdev" '$3 == d { printf "[%d,%d]", $6, $10 }' /proc/diskstats)
[[ -z $diskio ]] && diskio=null

# Network: interface of the default route, bytes received / sent
iface=$(ip -4 route show default 2>/dev/null | awk '{ for (i=1;i<NF;i++) if ($i=="dev") { print $(i+1); exit } }')
net=null
if [[ -n $iface ]]; then
  net=$(awk -v i="$iface:" '$1 == i { printf "{\"iface\":\"%s\",\"rx\":%d,\"tx\":%d}", substr(i,1,length(i)-1), $2, $10 }' /proc/net/dev)
  [[ -z $net ]] && net=null
fi

# Processes: top 10 by CPU (measured over 0.6 s) and top 10 by memory
toplist=$(top -b -n 2 -d 0.6 -w 512 2>/dev/null | awk '
  /^ *PID/ { frame++; next }
  frame == 2 && NF >= 12 {
    cmd=$12
    for (k=13; k<=NF; k++) cmd = cmd " " $k
    gsub(/\\/, "\\\\", cmd); gsub(/"/, "\\\"", cmd)
    print $1 "\t" $9 "\t" $10 "\t" cmd
  }')
tojson() { awk -F'\t' '{ printf "%s{\"pid\":%d,\"cpu\":%s,\"mem\":%s,\"name\":\"%s\"}", (n++ ? "," : ""), $1, $2, $3, $4 }'; }
procs_cpu=$(printf '%s\n' "$toplist" | sort -t$'\t' -k2,2nr | head -n 10 | tojson)
procs_mem=$(printf '%s\n' "$toplist" | sort -t$'\t' -k3,3nr | head -n 10 | tojson)

printf '{"host":%s,"kernel":%s,"uptime":%s,"load":%s,"cpu":[%s],"freq":%s,"temp":%s,"mem":%s,"igpu":%s,"nv":%s,"disks":[%s],"diskio":%s,"net":%s,"procsCpu":[%s],"procsMem":[%s]}\n' \
  "$(json_str "$host")" "$(json_str "$kernel")" "$uptime" "$load" "$cpu" "$freq" "$temp" "$mem" "$igpu" "$nv" "$disks" "$diskio" "$net" "$procs_cpu" "$procs_mem"
