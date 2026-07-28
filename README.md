# openpreset

A lightweight, portable POSIX terminal suite for model & provider routing through [OpenRouter](https://openrouter.ai), with live cost/latency/uptime data, reusable presets, and dedicated launchers for top AI coding agents: **Claude Code (`cr`)**, **Kilo Code (`kr`)**, **Hermes Agent (`hr`)**, **OpenClaw (`or`)**, **Pi Agent (`pr`)**, and **Cline (`clr`)**.

<img width="1080" height="620" alt="demo" src="https://github.com/user-attachments/assets/f146a437-56d3-40c1-91ce-5782dda4a515" />

## What is  OpenPreset?

`openpreset` is an open-source POSIX shell suite that runs right before your favorite AI coding agent starts. It lets you choose which model your agent uses (via OpenRouter), view live metrics for every provider serving that model (cost, latency, uptime, throughput), set a priority order between providers, and save that order as a reusable, cloud-synced preset.

Presets aren't local-only settings. `openpreset` creates and manages them as real preset resources on your OpenRouter account using OpenRouter's API. Once created, a preset is addressable as `@preset/<slug>` from any OpenRouter-compatible client.

## Fast One-Command Installation

Install `openpreset` instantly on any Linux distribution (or macOS/BSD with POSIX shell):

```sh
curl -fsSL https://raw.githubusercontent.com/ZaituDev/OpenPreset/main/install.sh | sh
```

The installer automatically detects non-root vs `sudo` privileges:
- **User space**: Installs binaries to `~/.local/bin` and libraries to `~/.local/share/openpreset`.
- **System space**: Installs binaries to `/usr/local/bin` and libraries to `/usr/local/share/openpreset` (when run with `sudo`).

### Built-in Auto-Update

Keep `openpreset` updated to the latest release with a single command:

```sh
openpreset update
```

---

## Supported AI Coding Agents

`openpreset` includes dedicated individual launcher scripts for top coding agents:

| Launcher | Agent CLI | Exec Command | Description |
|---|---|---|---|
| **`cr`** | **Claude Code** | `claude` | Launches Anthropic's Claude Code CLI with OpenRouter routing |
| **`kr`** | **Kilo Code** | `kilo` | Launches Kilo Code CLI with model & preset routing |
| **`hr`** | **Hermes Agent** | `hermes` | Launches Hermes Agent CLI with OpenRouter API |
| **`or`** | **OpenClaw** | `openclaw` | Launches OpenClaw with OpenRouter endpoint setup |
| **`pr`** | **Pi Agent** | `pi` | Launches Pi Agent CLI with OpenRouter model selection |
| **`clr`** | **Cline** | `cline` | Launches Cline CLI with provider priority routing |
| **`openpreset`** | **Suite Manager** | `openpreset` | Suite manager, updater, and generic agent runner (`openpreset launch <agent>`) |

---

## Authentication & Credentials

Set your OpenRouter API key in your shell configuration (`~/.bashrc`, `~/.zshrc`, or `~/.profile`):

```sh
export OPENROUTER_API_KEY="sk-or-v1-..."
```

*(Note: `ANTHROPIC_AUTH_TOKEN` is also supported as a fallback).*

---

## At a Glance

- **Portable POSIX Shell**: Runs on any shell — `sh`, `bash`, `dash`, `zsh`, `ksh`, `busybox ash`. Zero compilation or heavy runtime overhead.
- **Model Catalogue Search**: Fzf-powered interactive search across OpenRouter models.
- **Live Provider Intelligence**: Compare real-time input/output pricing (per 1M tokens), 30-minute uptime %, TTFT latency (P50), and token throughput before launching.
- **Cloud Presets**: Create, edit, rename, backup, and restore presets directly linked to your OpenRouter account.
- **No Agent Modification**: Never modifies or proxies agent binaries — configures environment variables (`OPENROUTER_MODEL`, `ANTHROPIC_MODEL`, `OPENAI_BASE_URL`) and passes execution to the real agent CLI via `exec`.

---

## How It Works

```
Select model  (interactive fzf picker or numbered menu)
    ↓
Choose launch mode: Direct or Preset
    ↓
Direct → export OPENROUTER_MODEL / ANTHROPIC_MODEL and launch agent
         (OpenRouter default routing applies)
    ↓
Preset → provider intelligence table (cost, uptime, latency, throughput)
       → interactive provider priority ordering
       → creates/updates preset on OpenRouter account (@preset/<slug>)
    ↓
Launch Agent — with target agent model variable set to @preset/<slug>
```

---

## Building Release Packages

To build the architecture-neutral release tarball (`openpreset-v1.0.0.tar.gz`) and SHA-256 checksums for GitHub Releases:

```sh
./package.sh
```

Release assets generated in `dist/`:
- `openpreset-v1.0.0.tar.gz`
- `checksums.txt`

---

## Testing & Validation

`openpreset` ships with full POSIX shell regression test coverage:

```sh
./router/validate.sh        # Executes POSIX validation suite (73 passed / 0 failed)
python3 router/validate.py   # Python sanity check suite (53 passed / 0 failed)
```

---

## License

MIT — see [LICENSE](LICENSE).
