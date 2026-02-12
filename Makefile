PLUGIN_NAME=		gateway_exporter
PLUGIN_VERSION=		1.0
PLUGIN_COMMENT=		Prometheus exporter for OPNsense gateway metrics
PLUGIN_DEPENDS=		os-node_exporter${PLUGIN_PKGSUFFIX}
PLUGIN_MAINTAINER=	brendan@bgwlan.nl

.include "../../Mk/plugins.mk"
