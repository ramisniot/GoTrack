xml.instruct! :xml, :version=>"1.0"
xml.rss(:version=>"2.0", "xmlns:georss" => "http://www.georss.org/georss"){
  xml.channel{
    xml.title("GoTrack Location Feed for #{@device_name}")
    xml.link("http://www.gotrack.com")
    xml.description("Location Matters")
    xml.language("en-us")
    for location in @locations
      xml.item do
        xml.title("Location reading on " + location.recorded_at.rfc2822)
        if location.note != nil
        xml.description(location.note + location.short_address)
        else
        xml.description(location.short_address)
        end
        xml.georss(:point, "#{location.latitude.to_s}  #{location.longitude.to_s}")
        xml.speed(location.speed)
        xml.direction(location.direction)
        xml.pubDate(location.recorded_at.rfc2822)
        xml.eventType(location.show_event_type)
      end
    end
  }
}
