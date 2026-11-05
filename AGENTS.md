# AGENTS.md

Instructions for an AI agent asked to deploy this repo. Humans should read
[README.md](README.md) instead.

## If the user says "set this up for me"

Run these three commands. Do not ask the user anything first: the port is chosen
automatically and the key is auto-detected.

```bash
git clone https://github.com/hrodres/opencode-quota-dashboard.git
cd opencode-quota-dashboard
./install.sh --json
```

The last command prints **one JSON object on stdout** and nothing else. Parse it:

```json
{
  "ok": true,
  "url": "http://127.0.0.1:8100/",
  "local_url": "http://127.0.0.1:8100/",
  "port": 8100,
  "bind": "127.0.0.1",
  "key_source": "openclaw secret store",
  "key_tail": "-D5O",
  "upstream": "ok",
  "service": "opencode-quota-dashboard",
  "installed": 1,
  "answering": 1,
  "notes": "no authentication; keep it on loopback, a LAN or a VPN"
}
```

Use `url` verbatim in your reply to the user. Never reconstruct it, and never
assemble one yourself: when the bind is `0.0.0.0` the installer resolves the
machine's LAN address, because `http://0.0.0.0:PORT/` is not openable.

## Never ask about the bind address

`BIND` defaults to `auto` and resolves itself. Do not ask the user which address
to use, and do not stop to request permission: a deployment that halts on this
question is a failed deployment.

| Host | `auto` resolves to | Why |
|---|---|---|
| A machine with a graphical session (`DISPLAY`/`WAYLAND_DISPLAY` set) | `127.0.0.1` | The user has a browser on that machine |
| Headless: server, LXC, VPS, container | `0.0.0.0` | There is no browser there; loopback would be unreachable for the user |

So on a headless host the default is already reachable from another device, and
`url` in the JSON is the machine's LAN address. Just report it.

Override only when the user has a reason to: `BIND=127.0.0.1` to keep it strictly
local, `BIND=0.0.0.0` to force LAN on a machine that has a display.

There is no authentication. Say so once, plainly, when the bind is not loopback:
safe on a home LAN or over a VPN, unsafe on the open internet. Never publish the
port to the internet; offer WireGuard or an SSH tunnel instead.

## Decision table

| `ok` | `error` | What to do |
|---|---|---|
| `true` | `null` | Done. Report `url`. |
| `false` | `no API key found` | Ask the user for an opencode go key, then `export OPENCODE_GO_API_KEY=sk-...` and re-run. |
| `false` | `HTTP 401` | The key was found but rejected. It is the wrong key, or revoked. Ask for a new one. |
| `false` | `no free port in …` | Pass `--port 9000` (or any free port) to `serve.py`. |
| `false` | anything else | Show `error` and `next_action` to the user. Do not retry blindly. |

Exit codes: `0` ok, `1` bad environment, `2` key missing or unusable,
`3` install failed. The JSON is printed on stdout in every case, so prefer
parsing it over reading the exit code.

## Port choice

`PORT` defaults to `auto`: the first free port from 8099 upward. On a machine
where 8099 is already taken, it silently uses 8100, 8101, and so on. Pass
`PORT=8200` to force a starting point, or `--port 8200` to `serve.py`.

Do not hardcode 8099 in anything you write for the user.

## Getting the key

Resolution order, first match wins:

1. `OPENCODE_GO_API_KEY`
2. `OPENCODE_GO_KEY_FILE=/path`
3. `api_key` or `.opencode-key` next to `serve.py`
4. an existing OpenClaw install (`openclaw.json`, plain key or SecretRef)

If OpenClaw is installed on this machine with the `opencode-go` provider, source
4 works and there is nothing to configure. Check with:

```bash
python3 serve.py --check --json --port auto
```

## Never do this

- Never print, echo, log or paste the API key. `--check` exposes only its last 4
  characters for exactly this reason.
- Never write the key into a file that is tracked by git. `.gitignore` already
  covers `api_key`, `.opencode-key` and `*.key`.
- Never send the key to any host other than the opencode endpoint. The server
  already does the right thing; do not add a proxy or a relay.
- Never leave the dashboard unreachable. `BIND=auto` already picks the right
  address for the host; do not override it to loopback on a headless machine, and
  do not ask the user to choose.
- Never expose the port to the public internet. Suggest WireGuard or an SSH
  tunnel instead.

## Verifying without installing

```bash
python3 serve.py --check --json --port auto   # key + upstream + chosen port
python3 serve.py --bind 127.0.0.1 --port 8100 # foreground, for a quick look
curl -s http://127.0.0.1:8100/healthz
```

## Uninstalling

```bash
sudo systemctl disable --now opencode-quota-dashboard
sudo rm /etc/systemd/system/opencode-quota-dashboard.service
sudo systemctl daemon-reload
```

Delete the clone directory afterwards. `state.json` lives inside it and is
disposable.
