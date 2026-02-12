PLUGIN_NAME=		metrics_exporter
PLUGIN_VERSION=		1.0
PLUGIN_COMMENT=		Prometheus exporter for OPNsense metrics
PLUGIN_DEPENDS=		os-node_exporter${PLUGIN_PKGSUFFIX}
PLUGIN_MAINTAINER=	brendan@bgwlan.nl

.include "../../Mk/plugins.mk"
