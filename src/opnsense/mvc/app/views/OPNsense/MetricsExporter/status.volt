<script>
    $(document).ready(function() {
        updateServiceControlUI('metricsexporter');

        function escapeHtml(str) {
            return $('<span>').text(str).html();
        }

        function statusLabel(status) {
            switch (status) {
                case 'none':
                    return '<span class="label label-success">Online</span>';
                case 'down':
                case 'force_down':
                    return '<span class="label label-danger">Offline</span>';
                case 'loss':
                    return '<span class="label label-warning">Packetloss</span>';
                case 'delay':
                    return '<span class="label label-warning">Latency</span>';
                case 'delay+loss':
                    return '<span class="label label-warning">Latency, Packetloss</span>';
                default:
                    return '<span class="label label-default">Pending</span>';
            }
        }

        function loadStatus() {
            $("#btnRefreshProgress").addClass("fa-spinner fa-pulse");
            ajaxCall("/api/metricsexporter/status/gateway", {}, function(data, status) {
                $("#gatewayTableBody").empty();
                if (status == "success" && data['rows'] !== undefined) {
                    $.each(data['rows'], function(idx, gw) {
                        var row = '<tr>' +
                            '<td>' + escapeHtml(gw.name) + '</td>' +
                            '<td>' + escapeHtml(gw.description) + '</td>' +
                            '<td>' + statusLabel(gw.status) + '</td>' +
                            '<td>' + escapeHtml(gw.delay !== '~' ? gw.delay : '-') + '</td>' +
                            '<td>' + escapeHtml(gw.stddev !== '~' ? gw.stddev : '-') + '</td>' +
                            '<td>' + escapeHtml(gw.loss !== '~' ? gw.loss : '-') + '</td>' +
                            '<td>' + escapeHtml(gw.monitor) + '</td>' +
                            '</tr>';
                        $("#gatewayTableBody").append(row);
                    });
                    if (data['node_exporter_installed'] === false) {
                        $("#node_exporter_warning").show();
                    }
                } else {
                    $("#gatewayTableBody").append(
                        '<tr><td colspan="7">{{ lang._("Unable to fetch gateway status. Is the exporter running?") }}</td></tr>'
                    );
                }
                $("#btnRefreshProgress").removeClass("fa-spinner fa-pulse");
            });
        }

        $("#btnRefresh").click(function(event) {
            event.preventDefault();
            loadStatus();
        });

        loadStatus();
    });
</script>

<div class="alert alert-warning" role="alert" id="node_exporter_warning" style="display:none;">
    <b>{{ lang._('Warning:') }}</b>
    {{ lang._('The Prometheus Exporter plugin (os-node_exporter) is not installed. The metrics exporter writes metrics to the node_exporter textfile collector directory, which requires os-node_exporter to be installed and enabled.') }}
</div>

<div class="content-box">
    <table class="table table-striped table-condensed" id="gatewayTable">
        <thead>
            <tr>
                <th>{{ lang._('Gateway') }}</th>
                <th>{{ lang._('Description') }}</th>
                <th>{{ lang._('Status') }}</th>
                <th>{{ lang._('Delay') }}</th>
                <th>{{ lang._('Stddev') }}</th>
                <th>{{ lang._('Loss') }}</th>
                <th>{{ lang._('Monitor') }}</th>
            </tr>
        </thead>
        <tbody id="gatewayTableBody">
        </tbody>
        <tfoot>
            <tr>
                <td colspan="7">
                    <div class="pull-right">
                        <button class="btn btn-primary" id="btnRefresh" type="button">
                            <b>{{ lang._('Refresh') }}</b>
                            <span id="btnRefreshProgress" class="fa fa-refresh"></span>
                        </button>
                    </div>
                </td>
            </tr>
        </tfoot>
    </table>
</div>
