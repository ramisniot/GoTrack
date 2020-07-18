// Array of ids of readings to geocode
var rgeo_queued_message = null;

// Common variables
var last_sent = 0;
var send_timeout = 0;
var send_throttle_fast = 200;
var send_throttle_slow = 500;
var send_throttle = send_throttle_fast; // Max send for RG once every
var attempts_remaining = 10; // Avoid infinite iterates while using RG
var empty_count = 0;
var max_empties = 10; // Give up after 10 consecutive empty responses
var updated_readings = [];
var backoff = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7];

function load_rgeo_code() {
  $('.resolved-address').each(function() {
    var $link = $(this).find('a');
    if ($link.length == 0) {
      $(this).attr('title', $.trim($(this).text()));
    } else {
      $link.parent().attr('title', $.trim($link.text()));
    }
  });

  var reading_ids = [];

  $.each(readings, function(index, reading) {
    if (reading.address === null && reading.lat && reading.lng) {
      reading_ids.push(reading.id);
    } else {
      if (frm_index) {
        updateDeviceAddress(reading);
      }
    }
  });

  if (reading_ids.length > 0) {
    rgeo_queued_message = 'reading_ids=' + reading_ids.join(',');

    send_if_ready();
  }
}

function send_if_ready() {
  if (ready_to_send()) {
    if (rgeo_queued_message != null) {
      $.get('/geocoded_locations', rgeo_queued_message, function(data) {
        rgeo_received(data);
      }, 'json');

      rgeo_queued_message = null;
    }

    if (attempts_remaining > 0) {
      attempts_remaining--;
    }

    last_sent = (new Date()).getTime();
  } else {
    clearTimeout(send_timeout);
    send_timeout = setTimeout('send_if_ready()', Math.pow(2, backoff[empty_count]) * 1000);
  }
}

function ready_to_send() {
  if (attempts_remaining <= 0) return false;

  const date = new Date();

  return date.getTime() - last_sent > send_throttle;
}

// Handle response
var rgeo_received = function(payload) {
  if (payload && payload.data && payload.data.length) {
    $.each(payload.data, function(index, item) {
      switch(item.type) {
        case 'reading':
          var reading = getReadingById(item.id);

          if (reading) {
            reading.address = item.address;
            updated_readings.push(reading);
          }

          if (frm_index) {
            updateDeviceAddress(item);
          }
      }
    });

    send_throttle = send_throttle_fast;
    empty_count = 0;

    // We got data, so update the screen.
    showReadings();

    // We succeed on getting information so we should restart remaining attempts
    attempts_remaining = 120;

  } else {
    empty_count++;
    send_throttle = send_throttle_slow;

    if (empty_count >= max_empties) {
      attempts_remaining = 0;
    }
  }

  // To continue geocoding we should call again main method
  load_rgeo_code();
};

function showReadings() {
  $.each(updated_readings, function(index, reading) {
    // Update address for each updated reading
    $("#geocode_" + reading.id).html(reading.address);
  });

  updated_readings = [];
}
