# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Deploy

```sh
./build.sh <firewall-hostname>    # build .pkg on firewall, install, download to dist/
```

This syncs `Makefile`, `pkg-descr`, and `src/` to the firewall's plugins fork, builds with `make package`, installs the `.pkg`, and downloads it to `dist/`. Requires SSH access to an OPNsense box.

**Verification** (run on an OPNsense box with `opnsense/plugins` and `opnsense/core` repos):
```sh
make lint       # PHP syntax, model validation, class-filename match, executable perms
make style      # PSR-12 coding standard
```

**Service management** (on firewall):
```sh
configctl metrics_exporter start|stop|restart|status
configctl metrics_exporter reconfigure    # reload config via SIGHUP
```

## Architecture

OPNsense MVC plugin that exports Prometheus metrics via node_exporter's textfile collector.

### Privilege Separation

Two tiers:
1. **Root** (`generate_config.php`) — runs via configd before daemon starts, reads OPNsense model/config.xml, writes JSON config to `/usr/local/etc/metrics_exporter.conf`
2. **Nobody** (`metrics_exporter.php`) — daemon runs as `nobody` via `daemon -u nobody`, uses a minimal autoloader (`lib/autoload.php`) instead of `config.inc` to avoid needing config.xml access

All collectors query system data via `\OPNsense\Core\Backend` (configd socket), which works without root.

### Collector Auto-Discovery

Files in `collectors/` matching `*Collector.php` are auto-discovered by `lib/collector_loader.php`. The type key is derived by stripping `Collector` and lowercasing (e.g., `GatewayCollector.php` → `gateway`).

Each collector is a class with static methods:
- `name(): string` — display name for UI
- `defaultEnabled(): bool` — default toggle state
- `collect(): string` — returns Prometheus exposition text
- `status(): array` — returns data for the Status UI page (optional)

### Data Flow

```
UI save → API controller → OPNsense model (config.xml)
                         → configd reconfigure
                         → generate_config.php (root): model → JSON config
                         → SIGHUP → daemon reloads config
                         → collectors → .prom files (atomic write)
                         → node_exporter textfile collector → Prometheus scrape
```

### MVC Wiring

- `$internalModelName` in `Api/GeneralController.php` must match the `<id>` prefix in `forms/general.xml`
- Model fields go at root of `<items>` (no wrapper element)
- API routes: `/api/metricsexporter/*`, UI routes: `/ui/metricsexporter/*`
- `Api/ServiceController` inherits standard start/stop/status from `ApiMutableServiceControllerBase`

## Key Conventions

- All PHP scripts in `src/opnsense/scripts/` **must** be executable (`chmod +x`) — lint enforces this
- Collector filenames must match class names (`class-filename` lint check)
- Model XML: don't set `<Default></Default>` or `<Required>N</Required>` — they're implicit defaults
- BSD 2-Clause license header required in all PHP/inc files
- PSR-12 coding standard, max 120 char line length
- `prom_escape()` from `lib/prometheus.php` for Prometheus label values
- `escapeHtml()` / `$('<span>').text(val).html()` for all dynamic content in Volt templates
