//= require jquery
//= require shared/jquery-ui
//= require shared/jquery-ujs
//= require settings-form
//= require shared/moment.min
//= require shared/infobox
//= require flash_message
//= require add-to-homescreen
//= require modal.js.erb

$(function() {
    $('#act-as-if-account-form').on('change', '#current-account-id', function(event) {
        changeAccount(this);
    });
});

function changeAccount(select) {
    $('#new_account_id').val($('#current-account-id').val());
    select.form.submit();
}
