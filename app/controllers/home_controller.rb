class HomeController < ApplicationController
  before_filter :authorize

  DISPATCH_DEVICE_COUNT = 3

  def mobile_supported?
    true
  end

  def index
    respond_to do |format|
      format.mobile { redirect_to '/home/locations.mobile' }
      format.html do
        redirect_options = {
          format: params[:format],
          add_to_homescreen: params[:add_to_homescreen]
        }

        if user_session[:group_value] or current_user.default_home_selection.nil?
          redirect_options[:action] =
            current_user.default_home_action || user_session[:last_home_action] || 'locations'
        else
          redirect_options[:action] = 'show_devices'
          redirect_options[:group_type] = current_user.default_home_selection
        end

        redirect_to(redirect_options)
      end
    end
  end

  def dispatch_device
    setup_home_info
    user_session[:last_home_action] = 'locations'

    @dispatchable_devices = []
    @groups = []
    @show_default_devices = false
    @geocoding_result = Geokit::Geocoders::MultiGeocoder.geocode(params[:address])

    if params[:address].blank?
      flash.now[:error] = 'No dispatch address given'
    elsif @geocoding_result.street_address.nil?
      flash.now[:error] = 'Not a valid dispatch address'
    else
      user_session[:home_device] = nil

      conditions = {}
      if current_group_value == 'default'
        conditions[:group_id] = nil
      elsif current_group_value != 'all'
        conditions[:group_id] = current_group_value.to_i
      end

      @dispatchable_devices = all_devices(conditions).reject { |x| x.last_gps_reading.nil? }.
          sort_by { |x| x.distance_to(@geocoding_result.ll) }[0..(DISPATCH_DEVICE_COUNT - 1)]
      @groups = @dispatchable_devices.reject { |x| x.group.nil? }.map(&:group).uniq.sort_by(&:name)
      @show_default_devices = true
    end
  end

  def locations
    @from_locations = true
    setup_home_info
  end

  def vehicle_status
    @from_status = true
    setup_home_info
  end

  def statistics
    @from_statistics  = true
    setup_home_info
  end

  def maintenance
    @from_maintenance = true
    setup_home_info
  end

  def show_devices
    set_home_selection(params[:group_type]) unless params[:group_type].blank?
    case params[:frm]
    when'from_statistics'
      redirect_to action: 'statistics', format: params[:format]
    when 'from_maintenance'
      redirect_to action: 'maintenance', format: params[:format]
    when 'from_locations'
      redirect_to action: 'locations', format: params[:format]
    when 'from_status'
      redirect_to action: 'vehicle_status', format: params[:format]
    else
      redirect_to action: 'index', format: params[:format]
    end
  end

  private

  def setup_home_info
    user_session[:last_home_action] = params[:action]
    @device_count = current_account.provisioned_devices.count

    # Leaving this line in for a few days to remind myself that I only *think* it's wrong.  Delete this line and the next if no bugs in default group selection reported since 2013-02-18.  -ctk
    # set_home_selection(nil) if session[:group_value].nil?
    if current_group_value == 'all'
      if current_home_device
        @groups = []
        @show_default_devices = false
      else
        @groups = all_groups
        @show_default_devices = true
      end
    elsif current_group_value == 'default'
      @groups = []
      @show_default_devices = true
    else
      @groups = Group.where(id: current_group_value)
      @show_default_devices = false
    end

    # Get readings for geocode
    @rg_readings = []

    @groups.each do |group|
      @rg_readings.concat(group.get_readings_from_devices_for_rg)
    end
    if default_devices.any? && @show_default_devices
      default_devices.each do |device|
        if device.last_gps_reading && device.last_gps_reading.location.nil?
          @rg_readings.push(device.last_gps_reading)
        end
      end
    end

    enqueue_reading_ids_for_rg
  end
end
