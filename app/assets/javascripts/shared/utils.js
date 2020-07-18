// String trim functions
String.prototype.trim = function() {
    return this.replace(/^\s+|\s+$/g,"");
}
String.prototype.ltrim = function() {
    return this.replace(/^\s+/,"");
}
String.prototype.rtrim = function() {
    return this.replace(/\s+$/,"");
}

// Popup dynamically sized window
function popIt(url, name, props) {
    window.open(url, name, props);
}

function showLoginMessageForm() {
    $('#login_message_form').show();
    $('#special_message').hide();
}

function hideLoginMessageForm() {
    $('#login_message_form').hide();
    $('#special_message').show();
    return true;
}