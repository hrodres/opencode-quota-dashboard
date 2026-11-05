# opencode-quota-dashboard

A tiny, dependency-free dashboard for your **opencode go** quota.

Three buckets — rolling 5-hour, weekly and monthly — plus a projection of where
the monthly bucket will land at reset, so you see trouble before it arrives.

**Works anywhere Python runs.** No OpenClaw, no Node, no pip, no build step.
**Agent-installable:** one command, no prompts, one JSON object back.

## Why

opencode go exposes a usage endpoint, but the numbers are bare JSON. This renders
them as one dark card you can leave open in a tab or pin to a phone's home
screen — and it tells you what the raw numbers don't: *at the current burn rate,
when do I run out?*

## Highlights

- **No dependencies.** Python 3.9+ standard library. The page is a single
  self-contained HTML file: no CDN, no fonts, no build.
- **Your key never leaves your machine.** The server reads it locally and uses it
  only in an outbound request header. Nothing but percentages reaches the browser.
- **Model-agnostic.** No model names and no pricing tables anywhere, so the
  dashboard behaves the same whatever model your account uses.
- **Never breaks.** If the upstream fails it keeps serving the last good reading,
  flags it stale, and marks it amber.
- **Querying `/usage` costs no quota.** It is a billing endpoint, not inference.

## Requirements

- Python 3.9 or newer.
- An opencode go API key. That's all.

OpenClaw is **optional**. If you happen to run it, the key is picked up
automatically — but nothing here needs it.

## Getting your key in

Provide it in any of these ways. The first match wins, in this order:

| # | Method | How |
|---|---|---|
| 1 | Environment variable | `export OPENCODE_GO_API_KEY=sk-...` |
| 2 | Key file by path | `export OPENCODE_GO_KEY_FILE=/path/to/key` |
| 3 | Key file next to the script | `echo 'sk-...' > api_key` |
| 4 | Existing OpenClaw install | `openclaw.json` (plain key or SecretRef) |

Methods 1–3 are completely independent of OpenClaw. Use them if you don't have
it. Method 4 also understands SecretRefs stored in the OpenClaw gateway's SQLite
database.

Verify which source was picked, without starting a server:

```bash
python3 serve.py --check
```

```
key    : found via OPENCODE_GO_API_KEY (51 chars, ending ...-D5O)
rolling : 3%  status=ok  resets=2026-11-05T18:46:30.000Z
weekly  : 50%  status=ok  resets=2026-11-09T00:00:00.000Z
monthly : 46%  status=ok  resets=2026-11-24T08:20:24.000Z
```

`--check` prints only the last 4 characters of the key, never the whole thing.

## Run

```bash
git clone https://github.com/hrodres/opencode-quota-dashboard.git
cd opencode-quota-dashboard
python3 serve.py
```

Then open <http://127.0.0.1:8099/>.

The port is picked automatically: `--port auto` starts at 8099 and takes the
first free one, so an occupied port is never a manual decision.

For LAN access:

```bash
python3 serve.py --bind 0.0.0.0
```

The bind address is chosen for you (`BIND=auto`): **loopback** on a machine with
a graphical session, **LAN** on a headless host such as a server, LXC or VPS
where loopback would be unopenable. That way a delegated deploy works on the
first try instead of stopping to ask which address to use.

Override it when you have a reason: `--bind 127.0.0.1` to keep it strictly local.
There is no authentication, so the server warns on startup when the resulting
address is not loopback.

### Install as a service

```bash
./install.sh
```

The installer runs `--check` first, reports which key source it found, then
creates a systemd unit and confirms the URL answers before returning. Without
systemd write access it prints the foreground command instead. It never prompts,
never asks for, copies or prints your key.

### Let an agent deploy it

You do not have to read any of the above. Paste this into OpenClaw (or any
coding agent with shell access) and it has everything it needs:

> Clone https://github.com/hrodres/opencode-quota-dashboard and set it up for
> me. Follow its AGENTS.md. Tell me the URL when it answers.

That is the whole instruction. Nothing else is required: `AGENTS.md` in the repo
is written for the agent, not for you, and covers the port, the key, the service
and what to do when something fails.

Under the hood the agent runs one command, which prints **exactly one JSON
object on stdout** and nothing else:

```bash
./install.sh --json
```

```json
{
  "ok": true,
  "url": "http://192.168.1.50:8100/",
  "local_url": "http://127.0.0.1:8100/",
  "port": 8100,
  "bind": "0.0.0.0",
  "key_source": "openclaw secret store",
  "key_tail": "-D5O",
  "upstream": "ok",
  "installed": 1,
  "answering": 1
}
```

`url` is the one to open from another device; `local_url` is the loopback one.
When bound to loopback they are equal. `key_tail` is the last 4 characters only —
never the key.

#### If you want it reachable from your phone

On a headless host this already works: `BIND=auto` resolves to the LAN address,
and the `url` you get back opens from any device on your network.

The only case that needs a word from you is a **desktop with a browser**, where
`auto` correctly picks loopback. Say so and it will switch:

> ...and I want to open it from my phone on the same WiFi.

There is **no authentication** either way — keep it indoors, or reach it over
WireGuard.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `OPENCODE_GO_API_KEY` | — | Your key (highest priority) |
| `OPENCODE_GO_KEY_FILE` | — | Path to a file containing the key |
| `OPENCODE_GO_USAGE_URL` | opencode endpoint | Override the API endpoint |
| `PORT` | `auto` from `8099` | HTTP port, or the first free one |
| `BIND` | `auto` | Listen address; `auto` = loopback with a display, LAN when headless |
| `CACHE_TTL` | `60` | Upstream cache, seconds |
| `STALE_AFTER` | `300` | Age at which data is flagged stale |
| `STATE_FILE` | `./state.json` | Where usage samples are kept |
| `GO_TZ` | `UTC` | Timezone for log timestamps |
| `OPENCLAW_HOME` | `~/.openclaw` | Only used for the optional OpenClaw path |

Command-line flags `--port` (integer or `auto`), `--bind`, `--json` and `--check`
override the environment.

## Endpoints

| Route | Content |
|---|---|
| `/` | The dashboard |
| `/quota.json` | Live quota, cached 60 s |
| `/healthz` | `{ok, age_s, stale, error}` |

`/quota.json` exists because the page consumes it, and stays useful if you want
to build another client on top.

Only `GET` is implemented; other methods return `501`. The server does not serve
its own source, `state.json`, or any file outside the two HTML routes.

## How the projection works

The server samples the monthly percentage every 10 minutes and keeps 7 days of
history in `state.json`. Burn rate is the slope across those samples, so the
estimate reflects *your* actual usage rather than a guess.

The first hours after a fresh install have no history. Until enough exists the
projection assumes even consumption and labels the basis `estimated cycle`; once
two samples are in, it switches to `history N h`.

If the bucket is projected to run dry before the reset, the card names the date
and how much time is left. Under 7 days it reports what remains (`5.2 d left`);
beyond that, how early relative to the reset (`14.3 d early`).

## Known limitations

- **No authentication.** Designed for loopback, a LAN, or a VPN. Anyone who can
  reach the port can read your quota percentages. They are not credentials, but
  do not put this on the open internet as-is.
- **Account-wide only.** The upstream endpoint aggregates the whole account;
  there is no per-model breakdown to display.
- **`state.json` is local and disposable.** Delete it any time; the projection
  rebuilds from scratch.
- **The usage endpoint is undocumented.** This relies on an endpoint that
  opencode may change. `OPENCODE_GO_USAGE_URL` lets you repoint it without
  editing code.

## Troubleshooting

```bash
python3 serve.py --check
```

| Output | Meaning |
|---|---|
| `key : NOT FOUND` | None of the four sources matched. Set one. |
| `HTTP 401` | The key is not valid. |
| `HTTP 429` | Rate limited. The 60 s cache normally prevents this. |
| `response has no usage field` | The endpoint changed shape. |

## License

MIT — see [LICENSE](LICENSE).
