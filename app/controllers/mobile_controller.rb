class MobileController < ApplicationController
  def index
  end

  def devices
    @devices = current_account.provisioned_devices
  end

  def show_device
    @device = Device.find_by_id(params[:id])
  end

  def view_all
    @marker_string = ""
    @range = ('A'..'Z').to_a
    @all_devices_with_map = current_account.provisioned_devices
  end
end
