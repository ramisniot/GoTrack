class Admin::OverviewController < ApplicationController
  unloadable # making unloadable per http://dev.rubyonrails.org/ticket/6001
  before_filter :authorize_super_admin
  layout 'admin'

  def index
    @current_user = current_user
    @total_accounts = Account.count
    @total_users = User.count
    @total_devices = Device.provisioned.count
    @total_device_profiles = DeviceProfile.count
  end

  def set_login_message
    if params[:login_message] && params[:login_message][:message]
      LoginMessage.instance.update_attribute(:message, params[:login_message][:message])
    end

    redirect_to :admin_root
  end

  def toggle_login_message
    msg = LoginMessage.instance
    msg.update_attribute(:is_active, !msg.is_active?)
  end
end
