//= require addtohomescreen

$(function() {
  var url = window.location.protocol + '//' + window.location.hostname + (window.location.port ? ':' + window.location.port: '')
  if (url.searchParams && url.searchParams.get('add_to_homescreen')) {
    history.replaceState('', window.document.title, url.href.replace(url.search, ''));
    addToHomescreen({ displayPace: 1 });
  }
  else {
    addToHomescreen({ maxDisplayCount: 1 });
  }
});
