$(function() {

    $("#maintenance_from_date_picker").datepicker({
      changeMonth: true,
      altFormat: "yy-mm-dd",
      dateFormat: "M d, yy"
    });

    $("#maintenance_to_date_picker").datepicker({
      changeMonth: true,
      altFormat: "yy-mm-dd",
      dateFormat: "M d, yy"
    });

    // Handle mileage/time change while creating a maintenance
    $('#maintenance_type_task_0').change(function() {
        if ($('#maintenance_type_task_0').is(':checked')) {
            $('#date').show();
            $('#mileage').hide();
        }
    });
    $('#maintenance_type_task_1').change(function() {
        if ($('#maintenance_type_task_1').is(':checked')) {
            $('#date').hide();
            $('#mileage').show();
        }
    });
});

function showFromDatePicker() {
  $("#maintenance_from_date_picker").datepicker("show");
}

function showToDatePicker() {
  $("#maintenance_to_date_picker").datepicker("show");
}
