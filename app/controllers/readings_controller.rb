include ActionView::Helpers::DateHelper
include ApplicationHelper

class ReadingsController < ApplicationController
  before_filter :authorize_http, only: ['last', 'all']
  before_filter :authorize, except: ['last', 'all', 'public'] # Public readings don't require any auth

  def recent
    devices_lookup

    @rg_readings = @devices.collect(&:last_gps_reading).compact
    rg = @rg_readings.select { |r| r.location_id.nil? }
    rg.map(&:id).each_slice(500) { |rs| ReverseGeocoder.find_all_reading_addresses(rs) }

    respond_to do |format|
      format.xml { render layout: false }
      format.json
    end
  end

  def get_last_reading_info_for_device
    if reading = Device.find(params[:id]).last_gps_reading
      begin
        ReverseGeocoder.find_all_reading_addresses([reading.id])
      rescue
        Rails.logger.info "Error with get_last_reading_info_for_device reading_id: #{reading.id}"
        Rails.logger.info $!
      end
    end

    render json: reading_js(reading, false, false)
  end

  def get_last_reading_info_for_devices
    js_readings = []
    devices_lookup

    begin
      ReverseGeocoder.find_all_reading_addresses(@devices.collect(&:last_gps_reading_id).compact)
    rescue
      Rails.logger.info $!
    end

    @devices.each do |device|
      reading = device.last_gps_reading
      js_readings << reading_js(reading, false, false) if reading
    end

    render json: js_readings
  end

  # Display last reading for device
  def last
    device = Device.find(params[:id])
    if device.account_id == current_account.id
      @locations = [device.readings.first]
      @locations.first.try(:force_location)
      @device_name = device.name
    else
      @locations = Array.new
    end
    render layout: false, formats: :xml
  end

  # Display last reading for all devices under account
  def all
    @devices = current_account.provisioned_devices.includes(last_gps_reading: [:location, :geofence])
    render layout: false, formats: :xml
  end

  # New action to allow public feeds for devices
  def public
    @devices = Account.find_by_id(params[:id]).try(:provisioned_devices) || []
    render layout: false, formats: :xml
  end

  private

  def devices_lookup
    @user_pre = params[:id]

    ## For load testing purposes
    account = Account.find_by_id(params[:account_id]) if Rails.env =~ /test/
    account ||= current_account

    if @user_pre == 'default'
      @devices = account.provisioned_devices.where(group_id: nil)
    elsif @user_pre == 'undefined'
      @devices = account.provisioned_devices
    elsif group = account.groups.find_by_id(@user_pre)
      @devices = group.devices
    else
      @devices = account.provisioned_devices
    end
    @devices = @devices.includes(:geofence_violations, last_gps_reading: [:location, :geofence, :digital_sensor_reading, device: [:last_rg_reading, :group, :digital_sensors, :account]])
  end
end
