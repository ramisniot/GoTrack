$(document).ready(function() {
  $('#subnav_map').click(function() {
    var id = $('#main_table').attr("data-reading-id");
    showMap();
    zoomToReadingsBounds();
    if (id) {
      centerMapOnReading(id);
    };
  });

  $('#subnav_reports').click(function() {
    $("#main_table").css('display', 'block');
    $("#map-wrapper").css('display', 'none');
    $('#subnav_reports').addClass('reports-mobile-subnav--selected');
    $('#subnav_map').removeClass('reports-mobile-subnav--selected');
  });
})

function mobileShowAndCenterMap(id) {
  showMap();
  var reading = getReadingById(id);
  var point = new google.maps.LatLng(reading.lat, reading.lng);
  gmap.setCenter(point);
  openInfoWindowHtml(point, createReadingHtml(id), 'reports');
  zoomToReadingsBounds();
  centerMapOnReading(id);
}

function showMap() {
  $("#map-wrapper").css('display', 'block');
  $("#main_table").css('display', 'none');
  $('#subnav_map').addClass('reports-mobile-subnav--selected');
  $('#subnav_reports').removeClass('reports-mobile-subnav--selected');
  google.maps.event.trigger(map, 'resize');
  google.maps.event.trigger(map, 'resize');
}
