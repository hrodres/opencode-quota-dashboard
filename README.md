<div align="center">

# opencode-quota-dashboard

**Three quota buckets. One burn rate. The date you run dry — before you run dry.**

A single dark card for your **opencode go** quota, served by one Python file.
No dependencies, no build step, no Node, no CDN.

[![Python](https://img.shields.io/badge/python-3.9%2B-3776AB?logo=python&logoColor=white)](#requirements)
[![Dependencies](https://img.shields.io/badge/dependencies-0-brightgreen)](#highlights)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Single file](https://img.shields.io/badge/serves-one%20HTML%20file-black)](#endpoints)

```bash
git clone https://github.com/hrodres/opencode-quota-dashboard.git
cd opencode-quota-dashboard && python3 serve.py
```

</div>

---

## What it looks like

```
  opencode go                         10 Nov, 18:32   ● LIVE   ↻
  ─────────────────────────────────────────────────────────────
  Rolling    5-hour window       3 %   ▏▏▏                  in 4 h 8 min
  Weekly     weekly cycle        7 %   ▏▏▏▏▏                in 5 d 5 h
  Monthly    monthly cycle      67 %   ▏▏▏▏▏▏▏▏▏▏▏▏▏▏       in 13 d 13 h
             ▁▂▃█▄▂▁▁▂ ···································
             start 24 Oct        now                end 24 Nov
             How the cycle closes      closes at 94 %   margin 3.0 d
             Projected at reset                             94 %
             Remaining margin                               +6 %
             Burn rate                              2.0 of 2.4 %/d
```

The little bars above the projection line are **consumption per day**, YouTube
"most replayed" style: height is the data, colour is not.

## Why

opencode go exposes a usage endpoint, but it answers in bare JSON: three
percentages and three timestamps. That tells you where you are, never where you
are heading — and the monthly bucket is the one that can end your week.

This dashboard adds the only two numbers that answer that:

- **the ceiling** — `(100 − current) / days to reset`, exact arithmetic, no model.
  It is how much you can spend per day and still reach the reset alive.
- **the projected close** — current % plus your measured burn rate times the
  days left.

Read together they say something a percentage never can: *`2.0 of 2.4 %/d`* means
you are under the ceiling with a little air. *`3.8 of 2.4`* means you run dry
before the reset, and the card names the day.

## Highlights

- **Zero dependencies.** Python 3.9+ standard library. The whole UI is one
  self-contained HTML file: no CDN, no web fonts, no build.
- **Your key never leaves the machine.** It is read locally and used only in an
  outbound request header. The browser receives percentages, nothing else.
- **Model-agnostic.** No model names, no pricing tables. Same card whatever
  model your account uses.
- **Never breaks.** If upstream fails it keeps serving the last good reading,
  flags it stale and turns the pill amber, instead of blanking the page.
- **Querying `/usage` costs no quota.** It is a billing endpoint, not inference.
- **Installable by an agent.** One command, one JSON object back, no prompts.

## Requirements

Python 3.9 or newer and an opencode go API key. That is the whole list.

OpenClaw is **optional** — if you happen to run it, the key is picked up
automatically. Nothing here requires it.

## Getting your key in

First match wins:

| # | Method | How |
|---|---|---|
| 1 | Environment variable | `export OPENCODE_GO_API_KEY=sk-...` |
| 2 | Key file by path | `export OPENCODE_GO_KEY_FILE=/path/to/key` |
| 3 | Key file next to the script | `echo 'sk-...' > api_key` |
| 4 | Existing OpenClaw install | `openclaw.json` — plain key or SecretRef |

Methods 1–3 are fully independent of OpenClaw. Method 4 also understands
SecretRefs stored in the gateway's SQLite secret store.

Check which source was picked without starting a server:

```bash
$ python3 serve.py --check
key     : found via OPENCODE_GO_API_KEY (51 chars, ending ...-D5O)
rolling : 3%  status=ok  resets=2026-11-05T18:46:30.000Z
weekly  : 50% status=ok  resets=2026-11-09T00:00:00.000Z
monthly : 46% status=ok  resets=2026-11-24T08:20:24.000Z
```

`--check` prints the last 4 characters of the key and never the key itself.

## Run

```bash
python3 serve.py                 # http://127.0.0.1:8099/
python3 serve.py --bind 0.0.0.0  # reachable from your phone
```

`--port auto` starts at 8099 and takes the first free port, so an occupied port
is never a manual decision.

`BIND=auto` (the default) picks **loopback** on a machine with a graphical
session and **LAN** on a headless host, where loopback would be unopenable for
you. Override it when you have a reason. There is no authentication, so the
server warns on startup when the resulting address is not loopback.

### Install as a service

```bash
./install.sh
```

Runs `--check` first, reports which key source it found, writes a systemd unit
and confirms the URL answers before returning. Without systemd write access it
prints the foreground command instead. It never prompts, never copies or prints
your key.

### Let an agent deploy it

Paste this into OpenClaw, or any coding agent with shell access:

> Clone https://github.com/hrodres/opencode-quota-dashboard and set it up for
> me. Follow its AGENTS.md. Tell me the URL when it answers.

That is the entire instruction. `AGENTS.md` is written for the agent, not for
you, and already covers the port, the key, the service and the failure modes.

Under the hood it runs one command, which prints **exactly one JSON object**:

```bash
$ ./install.sh --json
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

`url` is the one to open from another device. `key_tail` is 4 characters, never
the key.

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
| `GO_TZ` | `UTC` | Timezone for days and log timestamps |
| `OPENCLAW_HOME` | `~/.openclaw` | Only used for the optional OpenClaw path |

Flags `--port` (integer or `auto`), `--bind`, `--json` and `--check` override the
environment.

## Endpoints

| Route | Content |
|---|---|
| `/` | The dashboard |
| `/quota.json` | Live quota + projection, cached 60 s |
| `/healthz` | `{ok, age_s, stale, error}` |

`/quota.json` exists because the page consumes it, and stays useful if you want
to build another client on top. Only `GET` is implemented; the server never
serves its own source or `state.json`.

## How the projection works

The server samples the monthly percentage every ten minutes and keeps **35 days**
in `state.json` — one full monthly cycle, which is what the per-day bars need in
order not to be born half empty.

**Burn rate** is the chord across the last **48 hours** of samples. Not the whole
history: a 7-day window drags in old spikes and, measured against this account's
data, overestimated the rate 3.3×. Against 24 h and 7 d, the 48 h window won at
the horizon that matters (MAE 3.09 vs 4.31 vs 3.39 pp at 24 h).

**The series is cut at the last reset.** If the percentage ever falls, everything
before that point belongs to another cycle and is discarded. Without this, a
window spanning a reset can come out positive by accident (5 % before, 8 % three
days later looks like +3) and yield a rate that is nonsense while looking fine.

**Days are marked incomplete, not guessed.** Each day's consumption is
`max − min` inside that day. For today, and for a first day whose samples start
late, that figure is a *minimum*, not a total — those bars are drawn at 55 %
opacity and say `in progress` / `partial day` on hover, so a floor is never
mistaken for a complete day.

**One rounding, two figures.** The projected close and the remaining margin are
derived from the same rounded number, so they always add up to 100. Rounding them
independently produced 87 % + 14 % = 101.

### What it can and cannot tell you

The upstream `percent` is an **integer**. There is no fractional reading to
average, so the rate is a chord between whole steps of a gauge, and the width of
that step limits how sharply the rate can be pinned down:

- With little movement in the window, ±1 point of quantisation is most of the
  signal. Three legitimate estimators of the same data can disagree by 40 % or
  more.
- Therefore the projected close is shown **without decimals**. A decimal would
  claim a resolution the source does not have.
- The verdict is robust even when the figure is not: *under* or *over* the
  ceiling holds across the whole plausible range of rates.

The honest reading is the comparison — **your rate against the ceiling** — not
the projected percentage on its own. The first days after a fresh install have no
history at all; until two samples exist the basis reads `estimated cycle` and
assumes even consumption.

## Known limitations

- **No authentication.** Built for loopback, a LAN or a VPN. Percentages are not
  credentials, but do not put this on the open internet as-is.
- **Account-wide only.** The endpoint aggregates the whole account; there is no
  per-model breakdown to display.
- **`state.json` is local and disposable.** Delete it any time; the projection
  rebuilds from scratch. Raising retention does not recover what an older,
  shorter retention already purged — a cycle in progress keeps its gap.
- **The usage endpoint is undocumented.** opencode may change it.
  `OPENCODE_GO_USAGE_URL` repoints it without editing code.

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
| Projection hidden | Not enough history yet, or the reset has passed. |

## License

MIT — see [LICENSE](LICENSE).
