# os-gateway-exporter

OPNsense plugin that exports gateway monitoring metrics in Prometheus format.

A PHP daemon polls the dpinger unix sockets at a configurable interval and writes
Prometheus-format metrics to the node_exporter textfile collector directory. This
makes gateway status, latency, packet loss, and RTT standard deviation available
for scraping by Prometheus via the existing node_exporter endpoint.

## Features

- Runs as a managed OPNsense service (start/stop/restart via UI or CLI)
- Configurable polling interval (5–300 seconds, default 15s)
- Configurable output path (default `/var/tmp/node_exporter/gateway.prom`)
- Web UI under **Services > Gateway Exporter** with three pages:
  - **Settings** — enable/disable, interval, output path
  - **Status** — live gateway status table with color-coded badges
  - **Log File** — daemon syslog entries via OPNsense's built-in log viewer
- Warning banner when `os-node_exporter` is not installed
- Atomic file writes (temp file + rename) to prevent partial reads
- SIGHUP support for configuration reload without restart
- Survives OPNsense major upgrades when installed as a package

## Prometheus Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `opnsense_gateway_status` | gauge | 0=down, 1=up, 2=loss, 3=delay, 4=delay+loss, 5=unknown |
| `opnsense_gateway_delay_seconds` | gauge | Round-trip time in seconds |
| `opnsense_gateway_stddev_seconds` | gauge | RTT standard deviation in seconds |
| `opnsense_gateway_loss_ratio` | gauge | Packet loss ratio (0.0–1.0) |
| `opnsense_gateway_info` | gauge | Informational metric (always 1) with status/monitor labels |

All metrics carry `name` and `description` labels. The `info` metric additionally
carries `status` (text) and `monitor` (monitor IP) labels.

## Prerequisites

- OPNsense 24.x or later
- `os-node_exporter` plugin installed and enabled (provides the textfile collector)

## Security

Exporter configuration is split into two phases:

1. **`generate_config.php`** runs as root via configd, reads the OPNsense model,
   and writes a JSON config file to `/usr/local/etc/gateway_exporter.conf`
2. **`gateway_exporter.php`** reads the JSON config for exporter settings and uses
   the OPNsense gateway API (`return_gateways_status`, `gatewaysIndexedByName`) for metric
   collection, ensuring compatibility with future dpinger changes

On reconfigure (settings save), configd regenerates the config file and sends
SIGHUP to the daemon.

Hardening:
- Output path validated with strict regex (absolute path, `.prom` extension, no `..`)
- Path traversal blocked at both model and daemon level
- Atomic file writes with `0644` permissions
- XSS prevention in status page via HTML escaping of all dynamic values

## File Structure

The `src/` directory maps to `/usr/local/` on OPNsense.

```
Makefile                                                    # Plugin metadata
pkg-descr                                                   # Package description
src/
├── etc/inc/plugins.inc.d/
│   └── gateway_exporter.inc                                # Service + syslog registration
└── opnsense/
    ├── mvc/app/
    │   ├── controllers/OPNsense/GatewayExporter/
    │   │   ├── GeneralController.php                       # Settings UI controller
    │   │   ├── StatusController.php                        # Status UI controller
    │   │   ├── Api/GeneralController.php                   # Settings API
    │   │   ├── Api/ServiceController.php                   # Service start/stop/status API
    │   │   ├── Api/StatusController.php                    # Gateway status API
    │   │   └── forms/general.xml                           # Settings form definition
    │   ├── models/OPNsense/GatewayExporter/
    │   │   ├── GatewayExporter.php                         # Model class
    │   │   ├── GatewayExporter.xml                         # Model schema
    │   │   ├── ACL/ACL.xml                                 # Access control
    │   │   └── Menu/Menu.xml                               # UI menu entries
    │   └── views/OPNsense/GatewayExporter/
    │       ├── general.volt                                # Settings page
    │       └── status.volt                                 # Status page
    ├── scripts/OPNsense/GatewayExporter/
    │   ├── generate_config.php                             # Config generator (runs as root)
    │   ├── gateway_exporter.php                            # Daemon (runs as nobody)
    │   └── gateway_status.php                              # Status query script
    └── service/conf/actions.d/
        └── actions_gateway_exporter.conf                   # configd action definitions
```

## Development Deployment

For testing on a live OPNsense firewall without building a package:

### 1. Copy files to the firewall

```sh
FIREWALL=your-firewall-hostname

# Stage files
ssh $FIREWALL "mkdir -p /tmp/gw_exporter_deploy"
scp -r src/ $FIREWALL:/tmp/gw_exporter_deploy/

# Install to /usr/local/
ssh $FIREWALL "sudo cp -r /tmp/gw_exporter_deploy/src/etc/ /usr/local/etc/ && \
    sudo cp -r /tmp/gw_exporter_deploy/src/opnsense/ /usr/local/opnsense/ && \
    sudo chmod +x /usr/local/opnsense/scripts/OPNsense/GatewayExporter/generate_config.php && \
    sudo chmod +x /usr/local/opnsense/scripts/OPNsense/GatewayExporter/gateway_exporter.php && \
    sudo chmod +x /usr/local/opnsense/scripts/OPNsense/GatewayExporter/gateway_status.php"
```

### 2. Run the post-install sequence

This mirrors what `pkg install` does via the generated `+POST_INSTALL` script:

```sh
# Restart configd to pick up new/changed actions
ssh $FIREWALL "sudo service configd restart"

# Run model migrations (registers model schema)
ssh $FIREWALL "sudo /usr/local/opnsense/mvc/script/run_migrations.php OPNsense/GatewayExporter"

# Reload plugin configuration (flushes menu/ACL caches, registers syslog facility)
ssh $FIREWALL "sudo /usr/local/etc/rc.configure_plugins POST_INSTALL"
```

### 3. Enable and start the service

Either via the web UI at **Services > Gateway Exporter > Settings**, or via CLI:

```sh
ssh $FIREWALL "sudo configctl gateway_exporter start"
```

### 4. Verify

```sh
# Check service status
ssh $FIREWALL "sudo configctl gateway_exporter status"

# Check metrics file
ssh $FIREWALL "sudo cat /var/tmp/node_exporter/gateway.prom"

# Check node_exporter serves the metrics
ssh $FIREWALL "curl -s http://localhost:9100/metrics | grep opnsense_gateway"

# Check syslog
ssh $FIREWALL "sudo grep gateway_exporter /var/log/system/latest.log | tail -5"

# Test the status API (used by the Status page)
ssh $FIREWALL "sudo configctl gateway_exporter gateway-status"
```

### Redeploying after changes

After making code changes, repeat steps 1–2. If the service is already running, restart it:

```sh
ssh $FIREWALL "sudo configctl gateway_exporter restart"
```

## CLI Reference

```sh
# Service management
configctl gateway_exporter start
configctl gateway_exporter stop
configctl gateway_exporter restart
configctl gateway_exporter status

# Query gateway metrics (JSON)
configctl gateway_exporter gateway-status

# List registered services
pluginctl -s | grep gateway

# Run model migrations
pluginctl -M gateway_exporter
```

## License

BSD 2-Clause License. See individual source files for details.
