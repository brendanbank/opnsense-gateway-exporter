<script>
    $(document).ready(function() {
        var data_get_map = {'frm_general_settings':"/api/metricsexporter/general/get"};
        mapDataToFormUI(data_get_map).done(function(data) {
            formatTokenizersUI();
            $('.selectpicker').selectpicker('refresh');
        });

        updateServiceControlUI('metricsexporter');

        ajaxCall(url="/api/metricsexporter/status/gateway", sendData={}, callback=function(data,status) {
            if (status == "success" && data['node_exporter_installed'] === false) {
                $("#node_exporter_warning").show();
            }
        });

        $("#saveAct").click(function() {
            saveFormToEndpoint(url="/api/metricsexporter/general/set", formid='frm_general_settings',callback_ok=function() {
                $("#saveAct_progress").addClass("fa fa-spinner fa-pulse");
                ajaxCall(url="/api/metricsexporter/service/reconfigure", sendData={}, callback=function(data,status) {
                    updateServiceControlUI('metricsexporter');
                    $("#saveAct_progress").removeClass("fa fa-spinner fa-pulse");
                });
            });
        });
    });
</script>

<div class="alert alert-warning" role="alert" id="node_exporter_warning" style="display:none;">
    <b>{{ lang._('Warning:') }}</b>
    {{ lang._('The Prometheus Exporter plugin (os-node_exporter) is not installed. The metrics exporter writes metrics to the node_exporter textfile collector directory, which requires os-node_exporter to be installed and enabled.') }}
</div>

<div class="content-box" style="padding-bottom: 1.5em;">
    {{ partial("layout_partials/base_form", ['fields':generalForm,'id':'frm_general_settings']) }}
    <div class="col-md-12">
        <hr />
        <button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
    </div>
</div>
