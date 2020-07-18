"use strict";

var BackgroundReports = (function() {
  var STATE_MILEAGE_TYPE = 'state_mileage'

  return {
    setup_report_span_values:  function() {
      if($(this).val() == STATE_MILEAGE_TYPE)
        $('#scheduled_report_report_span_units').append($('<option value="3.Months">3 Months</option>'));
      else
        $('#scheduled_report_report_span_units option[value="3.Months"]').remove();
    },

    setup_device_type: function(content_id) {
      $(content_id)[0].selectedIndex = 0;
    },

    setup_devices: function(content_id) {
      $(content_id)[0].selectedIndex = 0;
    },

    setup_recur_checkbox: function() {
      $('#recur_interval')[0].style.display = this.checked ? 'inline' : 'none';
    }
  }
})();