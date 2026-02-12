#!/bin/sh
#
# Build an OPNsense plugin package (.pkg) for os-metrics_exporter.
#
# Usage: ./build.sh [firewall-hostname]
#
# The build must happen on an OPNsense/FreeBSD host (requires bmake, pkg).
# This script uploads the source, runs the build via SSH, and downloads
# the resulting .pkg file to dist/.
#

set -e

FIREWALL="${1:-${FIREWALL:?Set FIREWALL env var or pass hostname as argument}}"
REMOTE_DIR="/tmp/metrics_exporter_build"
PLUGIN_SUBDIR="net-mgmt/metrics_exporter"
LOCAL_DIST="dist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Directories required by the OPNsense plugin build system
BUILD_SUPPORT_DIRS="Mk Templates Scripts"

echo "==> Building on ${FIREWALL}"

# Verify build support files exist locally
for dir in ${BUILD_SUPPORT_DIRS}; do
    if [ ! -d "${SCRIPT_DIR}/tmp/plugins/${dir}" ]; then
        echo "ERROR: ${SCRIPT_DIR}/tmp/plugins/${dir} not found." >&2
        echo "Clone the plugins repo: git clone https://github.com/opnsense/plugins.git tmp/plugins" >&2
        exit 1
    fi
done

# Create remote build directory structure
echo "==> Creating remote build directory"
ssh "${FIREWALL}" "rm -rf ${REMOTE_DIR} && mkdir -p ${REMOTE_DIR}/${PLUGIN_SUBDIR}"

# Upload build support dirs (Mk/, Templates/, Scripts/)
echo "==> Uploading build system files"
for dir in ${BUILD_SUPPORT_DIRS}; do
    scp -rq "${SCRIPT_DIR}/tmp/plugins/${dir}" "${FIREWALL}:${REMOTE_DIR}/"
done

# Upload plugin source
echo "==> Uploading plugin source"
scp -q "${SCRIPT_DIR}/Makefile" "${FIREWALL}:${REMOTE_DIR}/${PLUGIN_SUBDIR}/"
scp -q "${SCRIPT_DIR}/pkg-descr" "${FIREWALL}:${REMOTE_DIR}/${PLUGIN_SUBDIR}/"
scp -rq "${SCRIPT_DIR}/src" "${FIREWALL}:${REMOTE_DIR}/${PLUGIN_SUBDIR}/"

# Run the build
echo "==> Running bmake package"
ssh "${FIREWALL}" "cd ${REMOTE_DIR}/${PLUGIN_SUBDIR} && sudo bmake package"

# Find and download the .pkg file
echo "==> Downloading package"
mkdir -p "${SCRIPT_DIR}/${LOCAL_DIST}"
scp -q "${FIREWALL}:${REMOTE_DIR}/${PLUGIN_SUBDIR}/work/pkg/*.pkg" "${SCRIPT_DIR}/${LOCAL_DIST}/"

# Show result
PKG_FILE=$(ls -1 "${SCRIPT_DIR}/${LOCAL_DIST}"/*.pkg 2>/dev/null | head -1)
if [ -n "${PKG_FILE}" ]; then
    echo "==> Package built successfully: ${PKG_FILE}"
else
    echo "ERROR: No .pkg file found" >&2
    exit 1
fi

# Clean up remote build directory
echo "==> Cleaning up remote build directory"
ssh "${FIREWALL}" "sudo rm -rf ${REMOTE_DIR}"

echo "==> Done"
