# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  KANSAS_CITY_LAT = 39.125212
  KANSAS_CITY_LNG = -94.551136

  def standard_date_and_time(target_datetime, previous_datetime = Time.now)
    result = standard_date(target_datetime, previous_datetime)
    return standard_time(target_datetime) if result == '&nbsp;'
    (result + ' ' + standard_time(target_datetime)).html_safe
  end

  def standard_date(target_datetime, previous_datetime = nil)
    result = target_datetime.in_time_zone.strftime(STANDARD_DATE_FORMAT) if target_datetime
    if result && (previous_datetime.nil? or result != previous_datetime.in_time_zone.strftime(STANDARD_DATE_FORMAT))
      target_datetime.in_time_zone.strftime(STANDARD_DATE_FORMAT)
    else
      '&nbsp;'.html_safe
    end
  end

  def standard_time(target_datetime)
    target_datetime.blank? ? 'N/A' : target_datetime.in_time_zone(current_user.time_zone).strftime(STANDARD_TIME_FORMAT).html_safe
  end

  def standard_full_datetime(datetime)
    "#{standard_date(datetime)} #{standard_time(datetime)}"
  end

  def standard_duration(duration)
    hours = duration.to_i / 60
    minutes = duration.to_i % 60
    sprintf('%02dh:%02dm', hours, minutes).html_safe
  end

  def standard_location(device, reading, no_link = false, is_mobile = false)
    content_tag :div do
      if reading.nil? || !reading.latitude || !reading.longitude
        'GPS Not Available'
      elsif no_link || current_user.nil? || current_user.is_read_only?
        if reading.geofence && reading.geofence_exit? # use location if it is outside the geofence
          get_location_address(reading)
        elsif reading.geofence
          reading.geofence.name
        else
          get_location_address(reading)
        end
      elsif reading.geofence
        if is_mobile
          reading.geofence.name
        else
          link_to(reading.geofence.name, edit_geofence_path(reading.geofence), { title: 'View this location', class: 'link-all1' }) + tag('br') + get_location_address(reading)
        end
      elsif is_mobile
        extract_location(reading)
      else
        link_to get_location_address(reading), new_geofence_path(geofence: { latitude: reading.latitude, longitude: reading.longitude, address: reading.short_address, radius: 0.1 }), { title: extract_location(reading), class: 'geocode' }
      end
    end.html_safe
  end

  def standard_location_text(device, reading)
    if reading
      reading.force_location
      reading.reload
    end

    if reading.nil? || reading.latitude.blank? && reading.longitude.blank?
      'GPS Not Available'
    elsif reading.geofence
      %(#{reading.geofence.name}; #{reading.short_address}).html_safe
    else
      reading.short_address.html_safe
    end
  end

  def display_result_count(page, total_count, per_page)
    page = 1 if page.to_i.zero?
    if total_count <= per_page
      "Displaying 1 - #{total_count} of #{total_count}"
    else
      approximate_number = per_page * page
      if approximate_number > total_count
        end_limit = total_count
        start_limit = total_count - (total_count % per_page)
        "Displaying #{start_limit + 1} - #{end_limit} of #{total_count}"
      else
        start_limit = approximate_number - per_page
        "Displaying #{start_limit + 1} - #{approximate_number} of #{total_count}"
      end
    end
  end

  def display_local_dt(timestamp)
    return unless timestamp

    timezone = current_user.time_zone || 'Central Time (US & Canada)'
    timestamp.in_time_zone(timezone).strftime COMPACT_TIMESTAMP_FORMAT
  end

  def billing_age_style(timestamp)
    if (timestamp.nil? || timestamp < 30.days.ago)
      ' style="background-color: red; color: white"'.html_safe
    elsif (timestamp < 25.hours.ago)
      ' style="background-color: yellow"'.html_safe
    end
  end

  def select_account(search_params, unassigned = true)
    select_tag('search[account_id_eq]', build_account_options(search_params, unassigned).html_safe, onchange: 'this.form.submit()', class: "form-select width--full").html_safe
  end

  def reading_js(reading, show_direction, show_phone_number)
    reading_data = {}
    if reading
      reading_data = {
        id: reading.id,
        lat: reading.latitude,
        lng: reading.longitude,
        speed: reading.speed,
        geofence: reading.fence_description,
        address: (reading.location ? reading.location.format_address : nil),
        note: reading.note,
        event: reading.show_event_type,
        dt: standard_date_and_time(reading.recorded_at),
        full_dt: standard_full_datetime(reading.recorded_at)
      }
      reading_data[:direction] = reading.direction if show_direction
      reading_data[:device_phone_number] = reading.device.phone_number if show_phone_number
    end

    reading_data.to_json
  end

  protected

  def full_device_status(device)
    last_status = device.latest_status
    return '-' if last_status == '-'

    links = {
      'Moving' => { title: 'View all readings', uri: action_reports_path(:all, device) },
      'Stopped' => { title: 'View stop report', uri: action_reports_path(:stop, device) },
      'Idle' => { title: 'View idle report', uri: action_reports_path(:idle, device) }
    }

    link_last_status = link_to(device.latest_status_description, links[last_status][:uri], title: links[last_status][:title])
    last_digital_sensor = device.latest_digital_sensor_status
    return link_last_status unless last_digital_sensor

    link_digital_sensor = link_to(last_digital_sensor, action_reports_path(:digital_sensor, device), title: 'View digital sensors')
    "#{link_last_status} / #{link_digital_sensor}"
  end

  def render_icon(i)
    case i
    when 2
      image_tag('icons/red_small.png', class: 'sel_icon__icon')
    when 3
      image_tag('icons/green_small.png', class: 'sel_icon__icon')
    when 4
      image_tag('icons/yellow_small.png', class: 'sel_icon__icon')
    when 5
      image_tag('icons/purple_small.png', class: 'sel_icon__icon')
    when 6
      image_tag('icons/dark_blue_small.png', class: 'sel_icon__icon')
    when 7
      image_tag('icons/grey_small.png', class: 'sel_icon__icon')
    when 8
      image_tag('icons/orange_small.png', class: 'sel_icon__icon')
    end
  end

  private

  def build_account_options(search_params, unassigned)
    selected_id = search_params.nil? ? '' : search_params[:account_id_eq]
    "".tap do |options|
      options << options_for_select([['All', '']], selected_id)
      options << options_for_select([['Unassigned', '0']], selected_id) if unassigned
      options << '<option disabled="disabled">--------------</option>'
      options << options_from_collection_for_select(Account.all.by_company, :id, :company, selected_id.to_i)
    end.html_safe
  end

  def get_location_address(reading)
    content_tag :div, class: 'geocode', id: ('geocode_' + reading.id.to_s) do
      extract_location(reading)
    end.html_safe
  end

  def extract_location(reading)
    if reading.location
      reading.location.format_address
    else
      'Getting Address...'
    end
  end

  def button_to_function(name, function = nil, html_options = {})
    onclick = "#{"#{html_options[:onclick]}; " if html_options[:onclick]}#{function};"

    tag(:input, html_options.merge(type: 'button', value: name, onclick: onclick))
  end

  def default_map_center_json
    (current_account.default_map_center || { lat: KANSAS_CITY_LAT, lng: KANSAS_CITY_LNG }).to_json
  end
end
