
$(function($){
    device_types_for_gateway();
    $('#device_gateway_name').change(device_types_for_gateway);
    $('#device_device_type').change(render_digital_sensor);
    $('#js-device-account').change(render_digital_sensor)
});

function render_digital_sensor(){
    var url = $('#device-form').data('url');
    var device_type = $('#device-form #device_device_type option:selected').val();
    var account_id = $('#device-form #js-device-account option:selected').val();
    var id = $('#device-form').data('id');
    var fullUrl = url + '?id=' + id + '&device_type=' + device_type + '&account_id=' + account_id;

    $.ajax({
        type: 'GET',
        url: fullUrl,
        beforeSend: function() {
            $('.digital-sensors-data').remove();
            $('.rss-public-radio-button').removeClass('rss-public-radio-button--sensors');
            $('#js-loader-digital-sensors').attr('class', '');
        },
        success: function(data){
            $('.digital-sensors-data').remove();
            if (data != ''){
                $('#last-device-form-element').after(data);
                $('.rss-public-radio-button').addClass('rss-public-radio-button--sensors');
            }
            else{
                $('.rss-public-radio-button').removeClass('rss-public-radio-button--sensors');
            }
            $('#js-loader-digital-sensors').attr('class', 'hide');
        }
    });
}

function device_types_for_gateway() {
    var device_id = $('#device-form').data('id');
    var gateway_name = $('#device_gateway_name').val();
    $.ajax({
        type: 'GET',
        url:'/admin/devices/on_change_gateway_get_device_types',
        data: {device_id: device_id, gateway_name: gateway_name},
        beforeSend: function() {
            $('.ajax-loader-gateway img').attr('class', '');
        },
        error: function() {
            $('.ajax-loader-gateway img').attr('class', 'hide');
        },
        success: function(data) {
            if (data != null) {
                $('#device_device_type').html(data);
            }
            render_digital_sensor()
        },
        complete: function(){
            $('.ajax-loader-gateway img').attr('class', 'hide');
        }
    });
}
