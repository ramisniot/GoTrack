class UtilsController < ApplicationController
  before_filter :authorize

  OVERLAY_TYPES = { 'geofences' => :geofences, 'placemarks' => :placemarks }

  def overlays_in_bounds
    x1 = params[:x1].blank? ? nil : params[:x1].to_f
    y1 = params[:y1].blank? ? nil : params[:y1].to_f
    x2 = params[:x2].blank? ? nil : params[:x2].to_f
    y2 = params[:y2].blank? ? nil : params[:y2].to_f

    if x1 && y1 && x2 && y2

      w = x2 - x1
      h = y2 - y1

      #slop factor, draw anything that's NEAR the window
      big_x1 = x1 - w
      big_x2 = x2 + w
      big_y1 = y1 - h
      big_y2 = y2 + h

      unless current_account.nil?
        device_ids = params[:d].blank? ? current_account.provisioned_devices.map(&:id) : params[:d].split(',').map(&:to_i)

        # 1/(69/radius) converts the radius into degrees latitude/longitude (conversion only accurate at equator, but oh well)
        # 2/(69/radius) doubles the radius, to help get nearby objects.
        # 2/(69/radius) = 0.0289855072 * radius
        @geofences = Geofence.includes(:polypoints).where("(account_id = ? OR (? AND device_id IN (?))) AND longitude >= (? - (0.0289855072 * radius)) AND longitude <= (? + (0.0289855072 * radius)) AND latitude >= (? - (0.0289855072 * radius)) AND latitude <= (? + (0.0289855072 * radius))", current_account.id, !!device_ids.empty?, device_ids, big_x1, big_x2, big_y2, big_y1).order('area DESC')

        geofence_json =  ('[' + @geofences.map { |x| x.to_json({ include: :polypoints, methods: [:square_bounds, :polygonal?] }) }.join(', ') + ']').html_safe
        render text: "{geofences: #{geofence_json}}"
        return true
      end
    end

    render text: "{geofences: []}"
  end

  def set_view_preference
    if params[:type]
      type = OVERLAY_TYPES[params[:type]]
      params[:checked] == 'y' ? current_user.view_overlays << type : current_user.view_overlays.delete(type)
      current_user.save(validate: false)
    elsif params[:map]
      current_user.update_attribute('default_map_type', params[:map]) if current_user
    end
    render nothing: true
  end

  def set_movement_alert
    device = Device.find_by_id params[:id]
    if device.nil?
      render text: 'Could not set EZ-Alert'
    elsif device.has_movement_alert_for_user(current_user)
      render text: 'EZ-Alert already set'
    else
      @movement_alert = MovementAlert.new(device_id: device.id, latitude: params[:lat], longitude: params[:lng], user_id: current_user.id)
      render text: @movement_alert.save ? 'EZ-Alert has been set' : 'Could not set EZ-Alert'
    end
  end
end
