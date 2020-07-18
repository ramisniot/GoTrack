class GroupsController < ApplicationController
  before_filter :authorize

  def index
    @groups = current_account.groups
  end

  def show
    load_group_by_id
  end

  def new
    set_device_and_groups
  end

  def edit
    load_group_by_id
    set_device_and_groups
  end

  def create
    @group = Group.new
    save_group
    if !validate_device_ids
      if @group.save
        update_devices
        flash[:success] = "Fleet " + @group.name + " was successfully added"
        redirect_to action: 'index'
      end
    else
      redirect_to action: "new"
    end

    set_device_and_groups
  end

  def update
    load_group_by_id

    @group = Group.find(params[:id])
    save_group
    if !validate_device_ids
      if @group.save
        Device.where('group_id = ?', @group.id).each do |device|
          device.group_id = nil
          device.save
        end
        first_set_icons_default
        update_devices
        flash[:success] = "Fleet #{@group.name} was updated successfully "
        redirect_to action: 'index'
      end
    else
      @group = Group.find(@group.id)
      flash[:group_name] = @group.name
      redirect_to action: 'edit', id: @group.id
    end

    set_device_and_groups
  end

  def destroy
    @group = Group.where('account_id = ?', current_account.id).find_by(id: params[:id])
    if @group
      flash[:success] = "Fleet #{@group.name} was deleted successfully "
      @group.destroy
      @group_devices = Device.where('group_id = ?', @group.id)
      @group_devices.each do |device|
        device.icon_id = '1'
        device.group_id = nil
        device.save
      end
    else
      flash[:error] = 'Invalid action'
    end
    redirect_to action: 'index'
  end

  private

  def save_group
    @group.name = params[:name]
    @group.max_speed = params[:max_speed]
    @group.image_value = params[:sel]
    @group.account_id = current_account.id
  end

  def first_set_icons_default
    @all_devices = Device.where('group_id = ? ', @group.id)
    @all_devices.each do |device|
      device.icon_id = '1'
      device.save
    end
    current_account.devices.where('group_id is NULL').each { |device| device.update_attribute(:icon_id, 1) }
  end

  def load_group_by_id
    if params[:id]
      @group = Group.find_by(id: params[:id], account_id: current_account.id)
      if @group
        flash[:group_name] = @group.name
        flash[:max_speed] = @group.max_speed
      else
        flash[:error] = 'Invalid action'
        redirect_to action: 'index'
      end
    end
  end

  def set_device_and_groups
    @devices = current_account.provisioned_devices
    @group_devices = current_account.provisioned_devices.where('group_id is not NULL')
  end

  def validate_device_ids
    if  params[:name] == "" || params[:select_devices].nil? || params[:select_devices].length == 0
      flash[:error] = ((@group.name == "") ? "Fleet name can't be blank <br/>" : "")
      flash[:error] << "You must select at least one device "
      flash[:group_name] = @group.name
      true
    end
  end

  def update_devices
    params[:select_devices].each do |device_id|
      device = Device.find(device_id)
      device.icon_id = params[:sel]
      device.group_id = @group.id
      device.save
    end
  end
end
