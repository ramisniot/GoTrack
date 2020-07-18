//= require background_reports
"use strict";

var OneTimeReports = (function() {
  return {
    init: function() {
      var group_id = '#one_time_report_report_params_group_id';
      var device_id = '#one_time_report_report_params_device_id';

      $(group_id).bind('change', function() { BackgroundReports.setup_device_type(device_id) });
      $(device_id).bind('change', function() { BackgroundReports.setup_devices(group_id) });
    }
  }
})();

$(function() {
  OneTimeReports.init();
});