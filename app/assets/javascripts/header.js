$(document).on('ready', function(e) {
  $(".user-options").on('click', function (e) {
    e.stopPropagation();
  });

  $(".user-name").on('click', function (e) {
    e.preventDefault();

    const optionsSwitch = $(".user-options");
    const caretIcon = $(".user-name__options-icon i");
    const userOptions = $(".user-options");

    if (optionsSwitch.hasClass("user-options--hidden")) {
      caretIcon.removeClass("fa-caret-down");
      caretIcon.addClass("fa-caret-up");

      userOptions.removeClass("user-options--hidden");
      userOptions.addClass("user-options--show");
    } else {
      caretIcon.removeClass("fa-caret-up");
      caretIcon.addClass("fa-caret-down");

      userOptions.removeClass("user-options--show");
      userOptions.addClass("user-options--hidden");
    }
  });
});
