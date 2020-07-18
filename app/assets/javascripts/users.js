function enablePasswords(enable) {
    if(enable) {
        $("#existing_password").prop('disabled', false);
        $("#new_password").prop('disabled', false);
        $("#confirm_new_password").prop('disabled', false);
        $("#existing_password").focus();
    } else {
        $("#existing_password").prop('disabled', true);
        $("#new_password").prop('disabled', true);
        $("#confirm_new_password").prop('disabled', true);
    }
}

function ValidateForm(){
    var emailID = $('#email').val().replace(/^\s/,"");
    if ((emailID.length <= 0))
    {
        //return true; // TODO only disallow blank if FLAG not checked
        alert("Email can't be blank.");
        $('#email').focus();
        return false
    }
    var emailID = $('#email');
    return CheckEmail(emailID);
}


function CheckEmail(FormField){
    var array = FormField.val().split(',');
    for(var i=0; i< array.length; i++){
        if(array[i].match(/[\w\-\.\+]+\@[a-zA-Z0-9\.\-]+\.[a-zA-z0-9]{2,4}$/)==null){
            alert(FormField.attr('title') + " is not in a valid format");
            FormField.focus();
            return false
        }
    }
    return true;
}
