$(document).on('ready', function () {
  var feedbackInput = document.getElementById("feedback");
  if (feedbackInput) feedbackInput.focus();

  $(".contact-form").on('submit', function (e) {
    if(this.feedback.value.trim().length < 5) {
      e.preventDefault();
      alert('Please provide your feedback');
      document.getElementById('feedback').focus();
    }
  });
});
