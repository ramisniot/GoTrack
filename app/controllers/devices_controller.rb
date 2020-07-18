class DevicesController < ApplicationController
  before_filter :authorize
  before_filter :sensors_params, only: [:update]
  INTERVAL_BEFORE_COMMAND_REQUEST_IS_STALE = 10.minutes

  def index
    # To allow groups to be selected on devices index page
    set_home_selection(params[:group_id]) if params[:group_id]
    @groups = current_account.groups
    load_devices_filtered_by_chosen_group
  end

  # User can edit their device
  def edit
    @device = Device.where("account_id = ? and provision_status_id=1", current_account.id).find_by(id: params[:id])
    if @device.nil?
      flash[:error] = 'Invalid action'
      redirect_to controller: 'devices'
    end
  end

  def update
    device = Device.where("account_id = ?", current_account.id).find_by(id: params[:id])

    #force the checkbox to have a valid value
    params[:device][:notify_on_first_movement] = params[:device][:notify_on_first_movement].blank? ? 0 : 1
    params[:device][:notify_on_gps_unit_power_events] = params[:device][:notify_on_gps_unit_power_events].blank? ? 0 : 1

    errors = device.sync_and_update(device_params)
    if errors.empty?
      flash[:success] = "#{device.name} was updated successfully"
      redirect_to controller: 'devices'
    else
      @device = Device.where("account_id = ? and provision_status_id=1", current_account.id).find_by(id: device.id)
      flash[:error] = device.errors.to_a.map { |e| e.gsub(/Imei Please choose/, 'Please choose') }.join('<br />')
      render action: 'edit'
    end
  end

  # User can delete their device
  def destroy
    if current_user.is_super_admin? && device = Device.find_by(id: params[:id])
      errors = device.delete
      if errors.empty?
        flash[:success] = "#{device.name} was deleted successfully"
      else
        flash[:error] = device.errors.to_a.join('<br />')
      end
    else
      flash[:error] = 'Invalid action'
    end
    redirect_to controller: "devices"
  end

  def search_devices
    @groups = current_account.groups
    group_id = user_session[:group_value]
    @from_search = true
    search_text = "%#{params[:device_search]}%"
    if params[:device_search] != ""
      @devices = group_id != 'all' ?
        current_account.provisioned_devices.where('devices.name ilike ?', search_text).where(group_id: (group_id == 'default' ? nil : group_id)) :
        current_account.provisioned_devices.where('devices.name ilike ?', search_text)
    else
      @devices = group_id != 'all' ?
        current_account.provisioned_devices.where(group_id: (group_id == 'default' ? nil : group_id)) :
        current_account.provisioned_devices
      params[:device_search] = nil
    end
    @search_text = params[:device_search].to_s
    params[:group_id] ? set_home_selection(params[:group_id]) : set_home_selection(nil)
    render action: 'index'
  end

  # Warning: this method is not used
  def find_now
    @original_referral_url = (params[:original_referral_url] || session[:referral_url])
    @device = current_account.provisioned_devices.find_by(id: params[:id])
    if @device.nil?
      flash[:error] = 'Invalid action'
      redirect_to controller: 'devices'
    else
      unless @device.request_location?
        flash[:error] = "This device does not support requesting its location."
      else
        last_request = @device.last_location_request
        #If there's a previous request, and that request never ended, and it started less than XX minutes ago...
        if last_request and last_request.end_date_time.nil? and last_request.start_date_time > INTERVAL_BEFORE_COMMAND_REQUEST_IS_STALE.ago
          flash[:error] = "A location request is already in progress. Please wait a few minutes and try again."
        else
          @device.submit_location_request
          flash[:success] = "The location has been requested"
          redirect_to @original_referral_url if @original_referral_url
        end
      end
    end
  end

  # Warning: This method is not used
  def choose_phone
    if (request.post? && params[:imei] != '')
      device = provision_device(params[:imei])
      if device
        # Removing for now. Causes 500 error in functional test on build box.
        #Text_Message_Webservice.send_message(params[:phone_number], "please click on http://www.db75.com/downloads/ublip.jad")
        redirect_to controller: 'devices', action: 'index'
      end
    end
  end

  #TODO: Search if this method is used, is like it isnt used.
  def group_action
    @user_prefence = params[:type]
    @user_prefence.inspect
    if params[:type] == "all"
      show_group_by_id
    elsif params[:type] == "edit"
    else
      @group_for_data = Group.where("id = ? ", @user_prefence)
      @devices_ids = GroupDevice.where('group_id = ?', @group_for_data)
      group_id = []
      count = 0
      @devices_ids.each do |group|
        group_id[count] = group.device_id
        count = count + 1
      end
      @devices = Device.where('id in (?) ', group_id)
      @all_devices = current_account.devices

    end
    # redirect_to controller:'reading',action:'recent'
    render :update do |page|
      page.replace_html "show_group", partial: "show_group_by_id", locals: { all_devices: @all_devices, group_for_data: @group_for_data, devices_ids: @devices_ids, devices: @devices }
      page.visual_effect :highlight, "show_group"
    end
  end

  # Warning : This method is not used
  # show the current user group
  def show_group
    show_group_by_id
  end

  # Warning: This method is not used
  # A device can provisioned
  def choose_mt
    if request.post? && params[:imei] != '' && params[:name] != ''
      device = provision_device(params[:imei])
      if !device.nil?
        redirect_to controller: 'devices', action: 'index'
      end
    else
      flash[:imei] = params[:imei]
      flash[:name] = params[:name]

      if (params[:imei] == "" && params[:name] == "")
        flash[:error] = "Name and IMEI can not be blank."
      elsif params[:imei] == ""
        flash[:error] = "IMEI can not be blank."
      elsif params[:name] == ""
        flash[:error] = "Name can not be blank."
      end
    end
  end

  private

  def device_params
    params.require(:device).permit(:thing_token, :name, :imei, :phone_number, :notify_on_gps_unit_power_events, :notify_on_first_movement, :idle_threshold,
                                   digital_sensors_attributes: %i(id address name low_label high_label notification_type))
  end

  def provision_device(imei, extras = nil)
    device = Device.find_by(imei: imei) # Determine if device is already in system

    # Device is already in the system so let's associate it with this account
    if device
      if device.provision_status_id.zero?
        device.account_id = current_account.id
        imei = params[:imei]
        device.name = params[:name]
        device.provision_status_id = 1
        device.save
        flash[:success] = "#{params[:name]} was provisioned successfully"
      else
        flash[:error] = 'This device has already been added'
        return nil
      end
      # No device with this IMEI exists so let's add it
    else
      device = Device.new
      device.name = params[:name]
      device.imei = params[:imei]
      device.thing_token = params[:thing_token]
      if !extras.nil?
        device.offline_threshold = extras[:offline_threshold].nil? ? nil : extras[:offline_threshold]
      end
      device.provision_status_id = 1
      device.account_id = current_account.id
      device.save
      flash[:success] = "#{params[:name]} was created successfully"
    end
    device
  end

  def show_group_by_id
    @group_for_data = current_account.groups
    group_id = []
    count = 0
    @group_for_data.each do |group|
      group_id[count] = group.id
      count = count + 1
    end
    @devices_ids = GroupDevice.where('group_id in (?)', group_id)
    group_id = []
    count = 0
    @devices_ids.each do |group|
      group_id[count] = group.device_id
      count = count + 1
    end
    @group_device_ids = GroupDevice.where('device_id in (?)', group_id).select(:device_id).distinct
    group_id = []
    count = 0
    @group_device_ids.each do |group|
      group_id[count] = group.device_id
      count = count + 1
    end
    @devices = Device.where('id in (?) AND account_id = ?', group_id, current_account.id)
    @device_all = @group_device_ids.nil? || @group_device_ids.length.zero? ?
      current_account.devices :
      Device.where('account_id = ? AND id not in (?) ', current_account.id, group_id)

    @devices_all = current_account.devices
  end
end
