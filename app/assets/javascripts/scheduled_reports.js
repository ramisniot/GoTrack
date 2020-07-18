//= require background_reports
"use strict";

var ScheduledReports = (function() {
  return {
    init: function() {
      var group_id = '#scheduled_report_report_params_group_id';
      var device_id = '#scheduled_report_report_params_device_id';

      $('#scheduled_report_report_type').bind('change', BackgroundReports.setup_report_span_values);
      $(group_id).bind('change', function() { BackgroundReports.setup_device_type(device_id) });
      $(device_id).bind('change', function() { BackgroundReports.setup_devices(group_id) });
      $('#scheduled_report_recur').bind('click', BackgroundReports.setup_recur_checkbox);
    }
  }
})();

$(function() {
  ScheduledReports.init();
});