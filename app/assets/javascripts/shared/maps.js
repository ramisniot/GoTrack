function initializeGoogleMap() {
  if (window.default_map_type == undefined) {
    window.default_map_type = google.maps.MapTypeId.ROADMAP;
  }

  var defaultMapCenter = $('#map').data('default-map-center');
  window.centerLatLng = new google.maps.LatLng(defaultMapCenter.lat, defaultMapCenter.lng);

  gmap = new google.maps.Map($('#map')[0], {
    zoom: 8,
    center: window.centerLatLng,
    streetViewControl: true,
    mapTypeId: window.default_map_type,
    gestureHandling: 'greedy',
    scrollwheel: true,
    mapTypeControl: true,
    mapTypeControlOptions: {
      mapTypeIds: [google.maps.MapTypeId.HYBRID, google.maps.MapTypeId.ROADMAP]
    },
    scaleControl: true,
    scaleControlOptions: {
      position: google.maps.ScaleControlStyle.RIGHT
    },
    styles: [{
      featureType: 'all',
      elementType: 'labels',
      stylers: [{
        visibility: 'on'
      }]
    }]
  });

  if (ie < 9) // Disable 45 degree view on browser's ie8, ie7, ie6, ie5 (causes to lose the session on some pages when zooming)
    gmap.setTilt(0);

  // Detect when info window is closed
  google.maps.event.addDomListener(gmap, "closeclick", function () {
    dev_id = false;
    highlightRow(0);
    window.activeDeviceId = null;
  });
  google.maps.event.addDomListener(gmap, "dragend", function () {
    new_drag_point = gmap.getCenter();
  });
  installMoveListener();
  google.maps.event.addDomListener(gmap, "infowindowopen", pauseMoveListener);
  google.maps.event.addDomListener(gmap, "maptypeid_changed", setMapTypePreference);
}

function installMoveListener() {
  window.moveListener = google.maps.event.addDomListener(gmap, "bounds_changed", function () {
    zoom = gmap.getZoom();
    if (window.mapOverlayVisibilityTimeout) {
      window.clearTimeout(window.mapOverlayVisibilityTimeout);
    }
    window.mapOverlayVisibilityTimeout = window.setTimeout("showVisibleMapOverlays();", 500);
  });
}

function pauseMoveListener() {
  google.maps.event.removeListener(window.moveListener);
  window.setTimeout("installMoveListener()", 1000);
}

function showVisibleMapOverlays() {
  //Don't draw anything if they're viewing the whole world map
  var bounds = gmap.getBounds();
  if (gmap.getZoom() < 6 || !bounds)
    return false;

  var ne = bounds.getNorthEast();
  var sw = bounds.getSouthWest();

  var x1 = sw.lng();
  var x2 = ne.lng();
  var y1 = ne.lat();
  var y2 = sw.lat();

  window.remote_url = "/utils/ACTION";
  window.remote_url += "?x1=" + x1 + "&y1=" + y1 + "&x2=" + x2 + "&y2=" + y2;

  if (window.device_id != undefined)
    window.remote_url += "&d=" + window.device_id;

  if (window.frameSpecificOverlays == null)
    initializeFrameSpecificOverlays();

  if (window.frameSpecificOverlayVisibilities == null)
    window.frameSpecificOverlayVisibilities = ['geofences', 'placemarks'];

  if (frameSpecificOverlayVisibilitiesIncludes('geofences') || frameSpecificOverlayVisibilitiesIncludes('placemarks'))
    fetchNewGeofencesAndPlacemarks();
}

function toggleGeofenceVisibility(obj) {
  if (!obj.checked && frameSpecificOverlayVisibilitiesIncludes('geofences')) {
    window.frameSpecificOverlayVisibilities = window.frameSpecificOverlayVisibilities.filter(function (item) {
      return item != 'geofences';
    });
    hideFrameSpecificOverlays('geofences');
    setViewPreference('geofences', false);
  }
  if (obj.checked && !(frameSpecificOverlayVisibilitiesIncludes('geofences'))) {
    window.frameSpecificOverlayVisibilities.push('geofences');

    //If "placemarks" was already checked, then we've already fetched geofences, and only need to draw them.
    if (frameSpecificOverlayVisibilitiesIncludes('placemarks')) {
      drawFrameSpecificOverlays('geofences');
    } else {
      fetchNewGeofencesAndPlacemarks();
    }
    setViewPreference('geofences', true);
  }
};

function fetchNewGeofencesAndPlacemarks() {
  if (window.remote_url) {
    $.ajax({ url: window.remote_url.replace('ACTION', 'overlays_in_bounds') }).done(function (transport) {
      var data = transport;
      var evaled = eval('(' + data + ')');
      hideFrameSpecificOverlays('all');
      window.frameSpecificOverlays['geofences'] = [];
      window.frameSpecificOverlays['placemarks'] = [];
      window.frameSpecificOverlays['messages'] = [];
      createFrameSpecificOverlays(evaled);
      drawFrameSpecificOverlays('all');
    });
  }
}

function hideFrameSpecificOverlays(kind) {
  if (kind == 'all') {
    hideFrameSpecificOverlays('geofences');
    hideFrameSpecificOverlays('placemarks');
  } else {
    if (window.frameSpecificOverlays[kind] != undefined)
      for (var i = 0; i < window.frameSpecificOverlays[kind].length; i++)
        window.frameSpecificOverlays[kind][i].setMap(null);
  }
}

function initializeFrameSpecificOverlays() {
  window.frameSpecificOverlays = { geofences: [], placemarks: [], messages: [] };
  window.frameSpecificOverlayLookupHash = {};
}

function createFrameSpecificOverlays(data) {
  var i;

  if (data['geofences'] != undefined)
    for (i = 0; i < data['geofences'].length; i++)
      window.frameSpecificOverlays['geofences'].push(data['geofences'][i]['polygonal?'] ? createPolygonalGeofence(data['geofences'][i]) : createCircularGeofence(data['geofences'][i]));

  if (data['placemarks'] != undefined)
    for (i = 0; i < data['placemarks'].length; i++)
      window.frameSpecificOverlays['placemarks'].push(createPlacemark(data['placemarks'][i]));

  if (data['messages'] != undefined) {
    //TODO: hack!
    var p_had_a_message = data['messages'][0] != undefined && data['messages'][0].match(/placemarks/) && frameSpecificOverlayVisibilitiesIncludes('placemarks');
    if (p_had_a_message || d_had_a_message) {
      createFadingMessage(data['messages'][0]);
    }
  }
}

function drawFrameSpecificOverlays(kind) {
  if (kind == 'all') {
    drawFrameSpecificOverlays('geofences');
    drawFrameSpecificOverlays('placemarks');

    //Automatically click on a placemark/geofence if we had clicked on it before and then it got redrawn
    if (window.frameSpecificOverlayLookupHash && window.autoOpenOverlayKey && window.frameSpecificOverlayLookupHash[window.autoOpenOverlayKey]) {
      google.maps.event.trigger(window.frameSpecificOverlayLookupHash[window.autoOpenOverlayKey], "click");
      window.autoOpenOverlayKey = null;
    }
  } else {
    if (window.frameSpecificOverlays[kind] != undefined && frameSpecificOverlayVisibilitiesIncludes(kind)) {
      for (var i = 0; i < window.frameSpecificOverlays[kind].length; i++) {
        window.frameSpecificOverlays[kind][i].setMap(gmap);
        window.frameSpecificOverlays[kind][i].setOptions({ zIndex: i });
      }
    }
  }
}

function createFadingMessage(text) {
  var element = $('#gmap_message');
  if (element == null)
    return false;

  element.innerHTML = '';
  if (text == undefined)
    text = '';
  if (text != '' && element != null) {
    element.style.visibility = 'visible';
    element.innerHTML = text;
  }
  //hide the message
  if (window.timeout != undefined) {
    window.clearTimeout(window.timeout);
  }
  window.timeout = window.setTimeout("$('#gmap_message').hide();", 5000);
}

function createPlacemark(placemark) {
  var icon = undefined;
  if (placemark['account_id'] != undefined) {
    icon = '<%= image_path("icons/orange_circle.png") %>';
  } else {
    icon = '<%= image_path("icons/red_circle.png") %>';
  }

  if (icon) {
    var marker = new google.maps.Marker({
      position: new google.maps.LatLng(placemark['latitude'], placemark['longitude']),
      title: placemark['name'],
      icon: icon
    });
    var placemarkInfoWindowHtml = "<div class='notTooWide'><b>Placemark:</b> " + placemark['name'] + "<br /><br /><a href='#' onclick='maxZoomTo(" + placemark['latitude'] + ', ' + placemark['longitude'] + ")'>Zoom In</a></div>";
    google.maps.event.addDomListener(marker, "click", function (mouseevent) {
      window.activeDeviceId = null;
      openInfoWindowHtml(new google.maps.LatLng(placemark['latitude'], placemark['longitude']), placemarkInfoWindowHtml);
    });
    window.frameSpecificOverlayLookupHash['p' + placemark['id']] = marker;
    return marker;
  } else {
    return undefined;
  }
}

function maxZoomTo(lat, lng) {
  gmap.setCenter(new google.maps.LatLng(lat, lng));
  gmap.setZoom(15);
}

function geofenceInfoWindowHtml(geofence) {
  return '<div class="tt_container">' +
    '<div class="tt_container__sidebar">' +
    '<div class="tt_container__sidebar__text_container">' +
    'Location' +
    '</div>' +
    '</div>' +
    '<div class="tt_container__body">' +
    '<p class="tt_container__body__name">' +
    geofence['name'] +
    '</p>' +
    '<div class="tt_container__body__link tt_container__body__link--large">' +
    geofence['address'] +
    '</div>' +
    '<br /><br />' +
    '<a class="tt_container__body__link" href="#" onclick="zoomToBoundsByCorner(' + geofence.square_bounds.join(', ') + ')">Zoom In</a>' +
    '</div>' +
    '<div class="clearfix"></div>'
  '</div>';
}

function zoomToBoundsByCorner(x1, y1, x2, y2) {
  gmap.fitBounds(new google.maps.LatLngBounds(new google.maps.LatLng(x1, y1), new google.maps.LatLng(x2, y2)));
}

function createPolygonalGeofence(geofence) {
  var stroke_weight = 3;
  var stroke_alpha = 0.75;
  var shading_alpha = 0.10;
  var polypoints_array = geofence['polypoints'].map(function (x) { return new google.maps.LatLng(x.latitude, x.longitude) });

  if ((polypoints_array[0] != undefined) && (polypoints_array[0].lat() != polypoints_array[polypoints_array.length - 1].lat()) || (polypoints_array[0].lng() != polypoints_array[polypoints_array.length - 1].lng())) {
    polypoints_array.push(polypoints_array[0]);
  }
  var polygon = new google.maps.Polygon({ path: polypoints_array, strokeColor: geofence['color'], strokeWeight: stroke_weight, strokeOpactiy: stroke_alpha, fillColor: geofence['color'], fillOpacity: shading_alpha });

  var gInfoWindowHtml = geofenceInfoWindowHtml(geofence);
  google.maps.event.addDomListener(polygon, "click", function (mouseevent) {
    window.activeDeviceId = null;
    openInfoWindowHtml(new google.maps.LatLng(geofence['latitude'], geofence['longitude']), gInfoWindowHtml, null, -110);
  });
  window.frameSpecificOverlayLookupHash['g' + geofence['id']] = polygon;
  return polygon;
}

function createCircularGeofence(geofence) {
  var stroke_weight = 3;
  var stroke_alpha = 0.75;
  var shading_alpha = 0.10;

  var circle = new google.maps.Circle({ center: new google.maps.LatLng(geofence['latitude'], geofence['longitude']), radius: geofence['radius'] * 1609.344, strokeColor: geofence['color'], strokeWeight: stroke_weight, strokeOpactiy: stroke_alpha, fillColor: geofence['color'], fillOpacity: shading_alpha });
  var gInfoWindowHtml = geofenceInfoWindowHtml(geofence);
  google.maps.event.addDomListener(circle, "click", function (mouseevent) {
    window.activeDeviceId = null;
    openInfoWindowHtml(new google.maps.LatLng(geofence['latitude'], geofence['longitude']), gInfoWindowHtml, null, -110);
  });
  window.frameSpecificOverlayLookupHash['g' + geofence['id']] = circle;
  return circle;
}

function setViewPreference(type, checked) {
  var url = "/utils/set_view_preference?type=" + type + "&checked=" + (checked ? 'y' : 'n');
  $.get(url);
  return true;
}

function setMapTypePreference() {
  var url = "/utils/set_view_preference?map=" + gmap.getMapTypeId();
  $.get(url);
  return true;
}

initializeFrameSpecificOverlays();



// ----------------------------------------------------------
// A short snippet for detecting versions of IE in JavaScript
// without resorting to user-agent sniffing
// ----------------------------------------------------------
// If you're not in IE (or IE version is less than 5) then:
//     ie === undefined
// If you're in IE (>=5) then you can determine which version:
//     ie === 7; // IE7
// Thus, to detect IE:
//     if (ie) {}
// And to detect the version:
//     ie === 6 // IE6
//     ie > 7 // IE8, IE9 ...
//     ie < 9 // Anything less than IE9
// ----------------------------------------------------------

// UPDATE: Now using Live NodeList idea from @jdalton

var ie = (function () {

  var undef,
    v = 3,
    div = document.createElement('div'),
    all = div.getElementsByTagName('i');

  while (
    div.innerHTML = '<!--[if gt IE ' + (++v) + ']><i></i><![endif]-->',
    all[0]
  );

  return v > 4 ? v : undef;

}());

function frameSpecificOverlayVisibilitiesIncludes(section) {
  auxiliar = window.frameSpecificOverlayVisibilities.filter(function (item) {
    return item == section;
  });
  return (auxiliar.length == 1)
}
