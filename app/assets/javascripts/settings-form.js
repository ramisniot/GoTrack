SettingsForm = (function() {
  var showOptionsAsDisabled = function(selector) {
    var container = $('#user-subscribed-notifications-disabled-js');
    container.html($('#user-subscribed-notifications-js').html());
    container.find('input').attr('disabled', 'disabled');
    container.addClass('settings-box--disabled');
  };

  var renderNotificationOptions = function(optionSelected) {
    if (optionSelected == 'notify_0') {
      $('#to_update_groups').hide();

      showOptionsAsDisabled();
      $('#user-subscribed-notifications-js').hide();
   }
   else {
     $('#user-subscribed-notifications-disabled-js').empty();
     $('#user-subscribed-notifications-js').show();

     optionSelected == 'notify_1' ? $('#to_update_groups').hide() : $('#to_update_groups').show();
   }
  };

  return {
    init: function() {
      renderNotificationOptions($('.enotify-option-js[checked]').attr('id'));
      $('.enotify-option-js').click(function() { renderNotificationOptions($(this).attr('id')) });
    }
  };
})();

$(function(){
  SettingsForm.init();
});
