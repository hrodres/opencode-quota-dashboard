#!/usr/bin/env bash
# Installer for opencode-quota-dashboard.
#
# Designed to be run non-interactively, including by an agent. It never prompts,
# never asks for or prints your API key, and with --json it prints a single JSON
# object on stdout that describes exactly what happened.
#
#   ./install.sh                 # install, human-readable output
#   ./install.sh --json          # install, one JSON object on stdout
#   ./install.sh --check --json  # do not install, just report key + port
#
# Exit codes: 0 ok, 1 bad environment, 2 key missing/unusable, 3 install failed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-auto}"
BIND="${BIND:-auto}"
SVC=opencode-quota-dashboard
MODE=install
JSON=0

for arg in "$@"; do
  case "$arg" in
    --json)  JSON=1 ;;
    --check) MODE=check ;;
    --yes|-y) ;;                      # accepted for familiarity, nothing to confirm
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) printf 'unknown argument: %s\n' "$arg" >&2; exit 1 ;;
  esac
done

say() { [ "$JSON" = 1 ] || printf '  %s\n' "$*"; }
jesc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

fail() {  # fail <code> <message> <next_action>
  if [ "$JSON" = 1 ]; then
    printf '{"ok":false,"error":"%s","next_action":"%s"}\n' "$(jesc "$2")" "$(jesc "$3")"
  else
    printf '\n  ERROR: %s\n  Next:  %s\n' "$2" "$3" >&2
  fi
  exit "$1"
}

# --- environment ------------------------------------------------------------
command -v python3 >/dev/null 2>&1 \
  || fail 1 "python3 not found" "install Python 3.9 or newer"
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' \
  || fail 1 "Python 3.9+ required" "upgrade Python"

# --- what will the server actually see? -------------------------------------
CHECK_JSON="$(python3 "$HERE/serve.py" --check --json --port "$PORT" --bind "$BIND" 2>/dev/null || true)"
if [ -z "$CHECK_JSON" ]; then
  fail 1 "serve.py --check produced no output" "run: python3 serve.py --check"
fi

py() { printf '%s' "$CHECK_JSON" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('$1') or '')" 2>/dev/null || true; }

KEY_OK="$(py key_found)"
KEY_SRC="$(py key_source)"
KEY_TAIL="$(py key_tail)"
CHOSEN_PORT="$(py port)"
URL="$(py url)"
LOCAL_URL="$(py local_url)"
BIND="$(py bind)"
UPSTREAM="$(py upstream)"
CHK_OK="$(py ok)"

if [ "$KEY_OK" != "True" ]; then
  if [ "$JSON" = 1 ]; then
    printf '%s\n' "$CHECK_JSON"
  else
    say "Key      : NOT FOUND"
    say "Installing anyway; the server will report 'no API key found' until one is set."
    say "Options:"
    say "  export OPENCODE_GO_API_KEY=sk-...        (in the service environment)"
    say "  OPENCODE_GO_KEY_FILE=/path/to/key"
    say "  echo 'sk-...' > $HERE/api_key && chmod 600 $HERE/api_key"
  fi
  if [ "$MODE" = check ]; then exit 2; fi
fi

if [ "$MODE" = check ]; then
  if [ "$JSON" = 1 ]; then printf '%s\n' "$CHECK_JSON"; else
    say "Key      : ${KEY_SRC:-none} (…${KEY_TAIL:-})"
    say "Upstream : ${UPSTREAM:-unavailable}"
    say "Port     : $CHOSEN_PORT"
    say "URL      : $URL"
  fi
  [ "$CHK_OK" = "True" ] && exit 0 || exit 2
fi

# --- service ----------------------------------------------------------------
INSTALLED=0
if [ -w /etc/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
  say "Installing systemd unit ..."
  sed -e "s|__DIR__|$HERE|g" \
      -e "s|__PORT__|$CHOSEN_PORT|g" \
      -e "s|__BIND__|$BIND|g" \
      -e "s|__USER__|$(id -un)|g" \
      -e "s|__HOME__|$HOME|g" \
      "$HERE/opencode-quota-dashboard.service" \
      > "/etc/systemd/system/$SVC.service"
  systemctl daemon-reload
  systemctl enable --now "$SVC" >/dev/null 2>&1 || true
  sleep 2
  if ! systemctl is-active --quiet "$SVC"; then
    fail 3 "service failed to start" "check: journalctl -u $SVC -n 40 --no-pager"
  fi
  INSTALLED=1
  say "Status   : $(systemctl is-active "$SVC")"
else
  say "No systemd write access; run it in the foreground:"
  say "  cd $HERE && python3 serve.py --bind $BIND --port $CHOSEN_PORT"
fi

# --- prove it answers -------------------------------------------------------
ALIVE=0
for _ in 1 2 3 4 5; do
  if curl -fsS --max-time 3 "${URL}healthz" >/dev/null 2>&1; then ALIVE=1; break; fi
  sleep 1
done

if [ "$INSTALLED" = 1 ] && [ "$ALIVE" != 1 ]; then
  fail 3 "service is active but $URL does not answer" "check: journalctl -u $SVC -n 40 --no-pager"
fi

if [ "$JSON" = 1 ]; then
  printf '{"ok":true,"url":"%s","local_url":"%s","port":%s,"bind":"%s","key_source":"%s","key_tail":"%s","upstream":"%s","service":"%s","installed":%s,"answering":%s,"notes":"%s"}\n' \
    "$(jesc "$URL")" "$(jesc "${LOCAL_URL:-$URL}")" "$CHOSEN_PORT" "$(jesc "$BIND")" "$(jesc "${KEY_SRC:-none}")" \
    "$(jesc "${KEY_TAIL:-}")" "$(jesc "${UPSTREAM:-unknown}")" \
    "$SVC" "$INSTALLED" "$ALIVE" \
    "$(jesc "no authentication; keep it on loopback, a LAN or a VPN")"
else
  say "URL      : $URL"
  [ "${LOCAL_URL:-$URL}" != "$URL" ] && say "Local    : $LOCAL_URL"
  say "Health   : $([ "$ALIVE" = 1 ] && echo 'answering' || echo 'not answering yet')"
  if [ "$BIND" = "127.0.0.1" ]; then
    say "Bound to loopback only (no authentication is built in)."
  else
    say "Reachable on your local network (no authentication is built in)."
  fi
fi
