xml.instruct! :xml, :version=>"1.0"
xml.rss(:version=>"2.0", "xmlns:georss" => "http://www.georss.org/georss"){
  xml.channel{
    xml.title("GoTrack Location Feed")
    xml.link("http://www.gotrack.com")
    xml.description("Location Matters")
    xml.language("en-us")
    for device in @devices
      reading = device.last_gps_reading
      xml.item do
        if(!reading.nil?)
          reading.force_location
          xml.title("Location reading for " + device.name + " on " + reading.recorded_at.rfc2822)
          xml.description(get_location_address(reading))
          xml.georss(:point, "#{reading.latitude} #{reading.longitude}")
          xml.speed(reading.speed)
          xml.direction(reading.direction)
          xml.pubDate(reading.recorded_at.rfc2822)
          xml.eventType(reading.show_event_type)
        end
      end
    end
  }
}
