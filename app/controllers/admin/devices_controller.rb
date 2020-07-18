class Admin::DevicesController < ApplicationController
  unloadable # making unloadable per http://dev.rubyonrails.org/ticket/6001
  before_filter :authorize_super_admin
  before_filter :sensors_params, only: %i(create update)
  layout 'admin'

  helper_method :device_imei_or_link

  def device_types
    @device_types ||= DeviceTypeProperties.by_gateway_name(Device::DEFAULT_DEVICE_GATEWAY).sort_by(&:label)
  end

  def device_imei_or_link(logical_device)
    gateway = Gateway.find(logical_device.gateway_name)
    return logical_device.imei unless gateway and logical_device.gateway_device
    %(<a href="#{gateway.device_uri}/#{logical_device.gateway_device.id}">#{logical_device.imei}</a>).html_safe
  end

  def index
    scope = params[:subdomain].blank? ? Device : Device.where(account_id: Account.where('subdomain ilike ?',"%#{params[:subdomain]}%").collect(&:id))
    scope = scope.where(provision_status_id: params[:status]) unless params[:status].blank?
    @devices = scope.search_for_devices(params[:search], params[:page]).includes(:account, :last_gps_reading).by_name
  end

  def show
    @device = Device.find(params[:id])
  end

  def new
    @device = Device.new
    set_accounts
  end

  def edit
    @device = Device.find(params[:id])
    set_accounts
  end

  def create
    params[:device][:device_type] = nil if params[:device] && params[:device][:device_type].blank?
    @device = Device.new(device_params)

    @device.is_public = params[:device][:is_public] == '1'

    errors = @device.sync_and_create
    if errors.empty?
      flash[:success] = "#{@device.name} created successfully"
      redirect_to admin_devices_path
    else
      flash.now[:error] = errors.uniq
        .map{ |error| "#{error.gsub('Imei Please', 'Please')}" }
        .join('<br />')

      set_accounts
      render :new
    end
  end

  def update
    @device = Device.find(params[:id])
    @device.is_public = !params[:device][:is_public].nil?
    # Let's determine if the device is being moved between accounts. If so, we need to nil the group_id
    unless @device.account_id.to_s == params[:device][:account_id]
      params[:device][:group_id] = nil
    end

    params[:device][:device_type] = nil if params[:device] && params[:device][:device_type].blank?

    errors = @device.sync_and_update(device_params)
    if errors.empty?
      flash[:success] = "#{@device.name} updated successfully"
      redirect_to admin_devices_path
    else
      flash[:error] = errors.join('<br />')
      set_accounts

      render :edit
    end
  end

  def destroy
    device = Device.find(params[:id])
    errors = device.delete

    if errors.empty?
      flash[:success] = "#{device.name} deleted successfully"
    else
      flash[:error] = device.errors.join('<br />')
    end

    if params[:account_id]
      redirect_to action: 'index', id: params[:account_id].to_s
    else
      redirect_to action: 'index'
    end
  end

  def clear_history
    unless device = Device.find_by_id(params[:id])
      flash[:error] = 'No device given'
      return redirect_to action: 'index'
    end

    if device.account
      flash[:error] = 'Device must not be assigned for history to be cleared'
    else
      begin
        device.clear_history

        flash[:success] = "#{device.name} history cleared"

      rescue
          flash[:error] = $!.to_s
      end
    end

    redirect_to edit_admin_device_path(id: device.id)
  end

  def on_change_gateway_get_device_types
    selected_device_type = Device.find(params[:device_id]).try('device_type') if params[:device_id].present?

    render partial: 'admin/devices/device_types', locals: { device_types: device_types, selected_device_type: selected_device_type }
  end

  def digital_sensor_form
    @device = (params[:id].empty? ? Device.new : Device.find(params[:id]))
    @device.device_type = params[:device_type] unless params[:device_type].empty?
    @device.account_id = params[:account_id] unless params[:account_id].empty?
    render partial: 'device_digital_sensor', locals: { device: @device, sensors: @device.sensors }
  end

  def device_params
    params.require(:device).permit(
      :thing_token, :name, :imei, :account_id, :profile_id, :gateway_name, :device_type, :provision_status_id, :is_public, :idle_threshold,
      digital_sensors_attributes: %i(id address name low_label high_label notification_type)
    )
  end

  private

  def set_accounts
    @accounts = Account.by_company.all
  end
end
