#!/bin/sh
#
# Build an OPNsense plugin package (.pkg) for os-metrics_exporter.
#
# Usage: ./build.sh [firewall-hostname]
#
# The build happens on an OPNsense/FreeBSD host using the plugins repo
# at /home/brendan/plugins. If the repo doesn't exist, it will be cloned.
# Local source is synced to the repo before building.
#

set -e

FIREWALL="${1:-${FIREWALL:?Set FIREWALL env var or pass hostname as argument}}"
REMOTE_PLUGINS="/home/brendan/plugins"
PLUGIN_SUBDIR="sysutils/metrics_exporter"
REMOTE_PLUGIN_DIR="${REMOTE_PLUGINS}/${PLUGIN_SUBDIR}"
LOCAL_DIST="dist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Building on ${FIREWALL}"

# Ensure the plugins repo exists on the firewall
echo "==> Checking for plugins repo on firewall"
ssh "${FIREWALL}" "
    if [ ! -d ${REMOTE_PLUGINS}/.git ]; then
        echo '    Cloning plugins fork...'
        git clone -b add-metrics-exporter https://github.com/brendanbank/plugins.git ${REMOTE_PLUGINS}
    fi
"

# Fetch latest and checkout the branch
echo "==> Fetching latest add-metrics-exporter branch"
ssh "${FIREWALL}" "
    cd ${REMOTE_PLUGINS} &&
    git fetch origin &&
    git checkout add-metrics-exporter &&
    git reset --hard origin/add-metrics-exporter
"

# Sync local source to the remote plugin directory
echo "==> Syncing local source to firewall"
ssh "${FIREWALL}" "rm -rf ${REMOTE_PLUGIN_DIR}/src && mkdir -p ${REMOTE_PLUGIN_DIR}"
scp -q "${SCRIPT_DIR}/Makefile" "${FIREWALL}:${REMOTE_PLUGIN_DIR}/"
scp -q "${SCRIPT_DIR}/pkg-descr" "${FIREWALL}:${REMOTE_PLUGIN_DIR}/"
scp -rq "${SCRIPT_DIR}/src" "${FIREWALL}:${REMOTE_PLUGIN_DIR}/"

# Clean previous build artifacts
echo "==> Cleaning previous build"
ssh "${FIREWALL}" "rm -rf ${REMOTE_PLUGIN_DIR}/work"

# Build the package
echo "==> Running make package"
ssh "${FIREWALL}" "cd ${REMOTE_PLUGIN_DIR} && make PLUGIN_DEVEL= package"

# Find the built .pkg
PKG_NAME=$(ssh "${FIREWALL}" "ls -1 ${REMOTE_PLUGIN_DIR}/work/pkg/*.pkg 2>/dev/null | head -1")
if [ -z "${PKG_NAME}" ]; then
    echo "ERROR: No .pkg file found on remote" >&2
    exit 1
fi
echo "==> Built: $(basename "${PKG_NAME}")"

# Install the package on the firewall
echo "==> Installing package"
ssh "${FIREWALL}" "sudo pkg add -f ${PKG_NAME}"

# Download the .pkg locally
echo "==> Downloading package"
mkdir -p "${SCRIPT_DIR}/${LOCAL_DIST}"
scp -q "${FIREWALL}:${PKG_NAME}" "${SCRIPT_DIR}/${LOCAL_DIST}/"
PKG_FILE="${SCRIPT_DIR}/${LOCAL_DIST}/$(basename "${PKG_NAME}")"
echo "==> Package: ${PKG_FILE}"

# Clean up build artifacts on the firewall
echo "==> Cleaning build artifacts"
ssh "${FIREWALL}" "rm -rf ${REMOTE_PLUGIN_DIR}/work"

echo "==> Done"
