class SettingsController < ApplicationController
  before_filter :authorize
  before_action :init_settings

  def index
  end

  def submit
    if current_user.is_admin?
      @account.company = params[:company]

      @account.max_speed = params[:max_speed]

      params[:time_zone] = nil if params[:time_zone].blank?
      @account.time_zone = params[:time_zone]

      @account.working_hours = params[:working_hours]
      @account.notify_on_working_hours = params[:notify_on_working_hours].blank? ? false : true
    end

    @user.enotify = params[:notify]
    @user.subscribed_notifications = subscribed_notifications_params

    if @account.save && @user.save
      update_group_notifications if @user.enotify == 2
      flash[:success] = 'Settings saved successfully'
    else
      flash[:error] = 'Error saving settings'
      logger.debug "Error was (#{$!}) or (#{@account.errors.to_a.inspect}) or (#{@user.errors.to_a.inspect})"
    end
    redirect_to action: 'index'
  end

  private

  def subscribed_notifications_params
    params.require(:subscribed_notifications)
  end

  def init_settings
    @account = current_account
    @account.working_hours ||= []
    @user = current_user
    @groups = current_account.groups
  end

  def  update_group_notifications
    @groups.each do |group|
      GroupNotification.delete_all "user_id = #{@user.id} AND group_id = #{group.id}"
      if params["rad_grp#{group.id}"]
        group_notification = GroupNotification.new
        group_notification.user_id = @user.id
        group_notification.group_id = params["rad_grp#{group.id}"]
        group_notification.save
      end
    end
  end
end
