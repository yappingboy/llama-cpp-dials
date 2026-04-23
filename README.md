# llama-cpp-dials

## Overview
KDE Plasma dial indicators that plug into a local llama-cpp instance, with an odometer that shows the token usage this session, and dials showing the current tokens/second and context window usage.

## Status
- Current phase: building
- Last updated: 2026-04-23

## Tech Stack
- Frontend: KDE Plasma 6 plasmoid (QML / Canvas)
- Backend: llama.cpp server REST API (`--metrics` flag required)

## Key Decisions
- **Prometheus `/metrics` endpoint over `/slots` JSON** — The metrics endpoint delivers token counters (`llama_prompt_tokens_total`, `llama_tokens_predicted_total`) and context fill (`llama_kv_cache_usage_ratio`) in a single request at a stable path. It does require passing `--metrics` to `llama-server`, which is documented in the install script.
- **Pure QML, no separate backend process** — `XMLHttpRequest` in QML handles the REST polling natively. This keeps installation to a single `kpackagetool6 --install` with no Python/D-Bus dependency.
- **Rate calculated from counter deltas, smoothed with EMA** — llama.cpp doesn't expose instantaneous generation speed through the metrics endpoint; we divide the change in total tokens by the poll interval and smooth it with a 0.7/0.3 exponential moving average so the dial decays cleanly when the model goes idle rather than jumping to zero.
- **Session tokens via stored baseline** — The server's counters are cumulative from startup. On first successful connect the widget snapshots the current values; session totals are the live counters minus that baseline. A counter regression (server restart) resets the baseline automatically.

## Open Issues
- [ ] Compact (panel icon) representation not yet implemented
- [ ] `llama_kv_cache_usage_ratio` stays at 0 when no slot is active — consider `/slots` fallback for idle state
- [ ] No Prometheus label support: metrics with `{…}` labels sum only the last label variant per metric name
- [ ] The dials don't move
- [ ] the session tokens don't tick up
- [ ] there are no settings. The user needs to be able to change the llama.cpp server and host.

## Installation

**Prerequisite:** start your llama.cpp server with `--metrics`:
```bash
./llama-server --metrics -m your-model.gguf
```

**Install the plasmoid:**
```bash
git clone https://github.com/yappingboy/llama-cpp-dials
cd llama-cpp-dials
bash install.sh
```

Then right-click the Plasma desktop → *Add Widgets* → search **llama-cpp Dials**.

Right-click the widget → *Configure* to set the API URL (default `http://localhost:8080`) and poll interval.

## Links
- Repo: https://github.com/yappingboy/llama-cpp-dials
- llama.cpp server docs: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- KDE Plasma widget authoring: https://develop.kde.org/docs/plasma/widget/

## File Layout
```
package/
  metadata.json                   plasmoid manifest (Plasma 6)
  contents/
    config/
      main.xml                    KConfig XT schema (apiUrl, pollInterval, maxTokensPerSec)
    ui/
      main.qml                    root PlasmoidItem — polling logic + layout
      DialGauge.qml               reusable Canvas arc gauge
      configGeneral.qml           settings page (cfg_ bindings)
install.sh                        kpackagetool6 install/upgrade helper
```
