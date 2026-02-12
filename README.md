# os-metrics-exporter

OPNsense plugin that exports OPNsense-specific metrics in Prometheus format via
the node_exporter textfile collector.

A PHP daemon runs as a managed OPNsense service and polls metrics at a
configurable interval, writing Prometheus-format `.prom` files to the
node_exporter textfile collector directory. This makes OPNsense-specific metrics
available for scraping by Prometheus via the existing node_exporter endpoint.

## Features

- **Modular collector architecture** — each metric source is a self-contained
  collector that can be independently enabled or disabled
- Runs as a managed OPNsense service (start/stop/restart via UI or CLI)
- Configurable polling interval (5–300 seconds, default 15s)
- Configurable output directory (default `/var/tmp/node_exporter/`)
- Web UI under **Services > Metrics Exporter** with three pages:
  - **Settings** — enable/disable service, interval, output directory, and
    per-collector toggles
  - **Status** — live Prometheus metrics output per collector
  - **Log File** — daemon syslog entries via OPNsense's built-in log viewer
- Warning banner when `os-node_exporter` is not installed
- Per-collector `.prom` files with atomic writes (temp file + rename)
- SIGHUP support for configuration reload without restart
- Automatic cleanup of `.prom` files when collectors are disabled

## Collectors

### Gateway (`gateway.prom`)

Polls dpinger via the OPNsense gateway API for status, latency, packet loss,
and RTT standard deviation per gateway.

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `opnsense_gateway_status` | gauge | `name`, `description` | 0=down, 1=up, 2=loss, 3=delay, 4=delay+loss, 5=unknown |
| `opnsense_gateway_delay_seconds` | gauge | `name`, `description` | Round-trip time in seconds |
| `opnsense_gateway_stddev_seconds` | gauge | `name`, `description` | RTT standard deviation in seconds |
| `opnsense_gateway_loss_ratio` | gauge | `name`, `description` | Packet loss ratio (0.0–1.0) |
| `opnsense_gateway_info` | gauge | `name`, `description`, `status`, `monitor` | Always 1; carries status text and monitor IP |

### Firewall / PF (`pf.prom`)

Queries pf state table and counter statistics via configd (`pfctl` requires root,
so the collector uses `\OPNsense\Core\Backend` to call configd actions).

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `opnsense_pf_states` | gauge | — | Current number of pf state table entries |
| `opnsense_pf_states_limit` | gauge | — | Hard limit on pf state table entries |
| `opnsense_pf_state_searches_total` | counter | — | Total pf state table searches |
| `opnsense_pf_state_inserts_total` | counter | — | Total pf state table inserts |
| `opnsense_pf_state_removals_total` | counter | — | Total pf state table removals |
| `opnsense_pf_counter_total` | counter | `name` | PF counter by type (match, bad-offset, fragment, short, normalize, memory, etc.) |

### Unbound DNS (`unbound.prom`)

Queries Unbound resolver statistics via configd (`unbound-control stats_noreset`).
Covers query volume, cache performance, memory usage, recursion time, answer
rcodes, query types, DNSSEC validation, and request list utilization.

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `opnsense_unbound_queries_total` | counter | — | Total DNS queries received |
| `opnsense_unbound_cache_hits_total` | counter | — | Total cache hits |
| `opnsense_unbound_cache_misses_total` | counter | — | Total cache misses |
| `opnsense_unbound_prefetch_total` | counter | — | Total prefetch actions |
| `opnsense_unbound_recursive_replies_total` | counter | — | Total recursive replies |
| `opnsense_unbound_answer_rcode_total` | counter | `rcode` | DNS answers by rcode (NOERROR, NXDOMAIN, SERVFAIL, etc.) |
| `opnsense_unbound_query_type_total` | counter | `type` | DNS queries by type (A, AAAA, PTR, MX, etc.) |
| `opnsense_unbound_query_opcode_total` | counter | `opcode` | DNS queries by opcode |
| `opnsense_unbound_memory_bytes` | gauge | `cache`, `module`, or `type` | Memory usage by component |
| `opnsense_unbound_requestlist_avg` | gauge | — | Average request list size |
| `opnsense_unbound_requestlist_max` | gauge | — | Maximum request list size |
| `opnsense_unbound_requestlist_overwritten_total` | counter | — | Overwritten request list entries |
| `opnsense_unbound_requestlist_exceeded_total` | counter | — | Exceeded request list entries |
| `opnsense_unbound_requestlist_current` | gauge | — | Current request list size |
| `opnsense_unbound_recursion_time_avg_seconds` | gauge | — | Average recursion time |
| `opnsense_unbound_recursion_time_median_seconds` | gauge | — | Median recursion time |
| `opnsense_unbound_tcp_usage` | gauge | — | Current TCP buffer usage |
| `opnsense_unbound_answer_secure_total` | counter | — | DNSSEC secure answers |
| `opnsense_unbound_answer_bogus_total` | counter | — | DNSSEC bogus answers |
| `opnsense_unbound_rrset_bogus_total` | counter | — | DNSSEC bogus RRsets |
| `opnsense_unbound_unwanted_queries_total` | counter | — | Unwanted queries |
| `opnsense_unbound_unwanted_replies_total` | counter | — | Unwanted replies |

## Prerequisites

- OPNsense 24.x or later
- `os-node_exporter` plugin installed and enabled (provides the textfile collector)

## Adding a Collector

Collectors are auto-discovered PHP files in `collectors/`. To add a new one:

1. Create `src/opnsense/scripts/OPNsense/MetricsExporter/collectors/<name>.php`
2. Define a class `<Name>Collector` with these static methods:
   - `name(): string` — human-readable name for the UI
   - `defaultEnabled(): bool` — whether enabled by default on fresh install
   - `collect(): string` — return Prometheus exposition format text
   - `status(): array` — return status data for the UI (optional)
3. Make the file executable (`chmod +x`)
4. Rebuild and install — the new collector appears automatically in Settings

## Security

Configuration is split into two privilege levels:

1. **`generate_config.php`** runs as root via configd, reads the OPNsense model,
   discovers collectors, merges defaults with user overrides, and writes a JSON
   config file to `/usr/local/etc/metrics_exporter.conf`
2. **`metrics_exporter.php`** (daemon) runs as `nobody`, reads the JSON config,
   and invokes each enabled collector's `collect()` method

Collectors that need root-level data (e.g., PF stats via `pfctl`) use
`\OPNsense\Core\Backend` to call configd actions rather than running
privileged commands directly.

Hardening:
- Output directory validated with strict regex (absolute path, no `..`)
- Path traversal blocked at both model and daemon level
- Atomic file writes with `0644` permissions
- XSS prevention in UI via HTML escaping of all dynamic values

## File Structure

The `src/` directory maps to `/usr/local/` on OPNsense.

```
Makefile                                                    # Plugin metadata
pkg-descr                                                   # Package description
src/
├── etc/inc/plugins.inc.d/
│   └── metrics_exporter.inc                                # Service + syslog registration
└── opnsense/
    ├── mvc/app/
    │   ├── controllers/OPNsense/MetricsExporter/
    │   │   ├── GeneralController.php                       # Settings UI controller
    │   │   ├── StatusController.php                        # Status UI controller
    │   │   ├── Api/GeneralController.php                   # Settings + collectors API
    │   │   ├── Api/ServiceController.php                   # Service start/stop/status API
    │   │   ├── Api/StatusController.php                    # Collector status API
    │   │   └── forms/general.xml                           # Settings form definition
    │   ├── models/OPNsense/MetricsExporter/
    │   │   ├── MetricsExporter.php                         # Model class
    │   │   ├── MetricsExporter.xml                         # Model schema
    │   │   ├── ACL/ACL.xml                                 # Access control
    │   │   └── Menu/Menu.xml                               # UI menu entries
    │   └── views/OPNsense/MetricsExporter/
    │       ├── general.volt                                # Settings page
    │       └── status.volt                                 # Status page
    ├── scripts/OPNsense/MetricsExporter/
    │   ├── collectors/
    │   │   ├── gateway.php                                 # Gateway metrics collector
    │   │   ├── pf.php                                      # PF/firewall metrics collector
    │   │   └── unbound.php                                 # Unbound DNS metrics collector
    │   ├── lib/
    │   │   ├── collector_loader.php                         # Collector auto-discovery
    │   │   └── prometheus.php                               # Prometheus helper (prom_escape)
    │   ├── generate_config.php                             # Config generator (runs as root)
    │   ├── list_collectors.php                             # List collectors (for API)
    │   ├── metrics_exporter.php                            # Daemon (runs as nobody)
    │   └── metrics_status.php                              # Status query script
    └── service/
        ├── conf/actions.d/
        │   └── actions_metrics_exporter.conf               # configd action definitions
        └── templates/OPNsense/Syslog/local/
            └── metrics_exporter.conf                       # Syslog filter
```

## Building

The plugin is built on a live OPNsense firewall using the standard plugins build
system:

```sh
# Clone the plugins build system (one-time)
git clone https://github.com/opnsense/plugins.git tmp/plugins

# Build the package (requires SSH access to an OPNsense box)
./build.sh <firewall-hostname>
```

The resulting `.pkg` file is written to `dist/`.

## Installation

```sh
FIREWALL=your-firewall-hostname
scp dist/os-metrics_exporter-devel-*.pkg $FIREWALL:/tmp/
ssh $FIREWALL "sudo pkg install -y /tmp/os-metrics_exporter-devel-*.pkg"
```

Then enable and configure via **Services > Metrics Exporter > Settings** in the
web UI.

## CLI Reference

```sh
# Service management
configctl metrics_exporter start
configctl metrics_exporter stop
configctl metrics_exporter restart
configctl metrics_exporter status

# Reconfigure (reload config without restart)
configctl metrics_exporter reconfigure

# List available collectors (JSON)
configctl metrics_exporter list-collectors

# Query collector metrics (JSON)
configctl metrics_exporter collector-status

# List registered services
pluginctl -s | grep metrics
```

## License

BSD 2-Clause License. See individual source files for details.
