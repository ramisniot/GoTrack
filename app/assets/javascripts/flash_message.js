$().ready(function(){
  $('#flash_message').addClass("flash-message-box--enter");

  setTimeout(function() {
    $('#flash_message').addClass("flash-message-box--leave");
    disappearFlash();
  }, 5000);

  $('#flash_message_close').click(function() {
    $('#flash_message').addClass("flash-message-box--leave");
    disappearFlash();
  })
})

function disappearFlash() {
  setTimeout(function() {
    $('#flash_message').addClass("flash-message-box--disappear");
  }, 700);
}
