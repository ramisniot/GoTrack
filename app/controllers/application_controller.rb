# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  SERVER_UTC_OFFSET = Time.now.utc_offset

  protect_from_forgery
  skip_before_filter :verify_authenticity_token, if: lambda { ios_request? }

  before_filter :ensure_request_format

  before_filter :set_navigation_format
  before_filter :set_page_title
  before_filter :create_referral_url
  before_filter :set_time_zone
  before_filter :exclude_read_only_users

  helper_method :all_groups, :all_devices, :current_account, :default_devices, :current_user, :current_locale, :current_group_value, :current_home_device, :view_user_and_unauthorized?, :desktop_override?, :mobile_browser?

  helper :layout, :page_entries

  def current_account
    return @current_account unless @current_account.nil?
    return @current_account = Account.find_by_id(session[:account_id]) unless session[:account_id].blank?
    return @current_account = current_user.account if current_user && current_user.account
    return nil
  end

  def current_locale
    if current_user.blank?
      @locale = get_locale_from_browser
    elsif current_user.locale.blank?
      @locale = current_user.locale
    end
    @locale = I18n.default_locale if @locale.blank?
    I18n.locale = @locale
  end

  def get_locale_from_browser
    if not request.env['HTTP_ACCEPT_LANGUAGE'].nil? and (locale_from_browser = request.env['HTTP_ACCEPT_LANGUAGE'].scan(/^[a-z]{2}/).first) and I18n.available_locales.collect(&:to_s).include?(locale_from_browser)
      locale_from_browser
    else
      I18n.default_locale.to_s
    end
  end

  def all_groups
    @all_groups ||= current_account.groups.includes(:devices)
  end

  def load_devices_filtered_by_chosen_group
    @devices = case current_group_value
                 when 'all'
                   current_account.provisioned_devices
                 when 'default'
                   current_account.provisioned_devices.where(group_id: nil)
                 else
                   current_account.provisioned_devices.where(group_id: current_group_value)
               end.includes(:last_gps_reading)
  end

  def all_devices(conditions = {})
    @all_devices ||= current_account.provisioned_devices.where(conditions)
  end

  def default_devices
    @default_devices ||= current_account.provisioned_devices.where(group_id: nil)
  end

  # NOTE this might be a nice mixin to be applied to ActiveRecord to complement #update_attribute
  def update_attribute_by_checkbox(model, attribute_name, checkbox_values)
    model.update_attribute(attribute_name, checkbox_values[attribute_name] == "on")
  end

  # NOTE this might be a nice mixin to be applied to ActiveRecord to complement #update_attributes
  def update_attributes_with_checkboxes(model, attribute_names, checkbox_values)
    checkbox_values ||= {}
    attribute_names.each do |single_attribute_name|
      update_attribute_by_checkbox(model, single_attribute_name, checkbox_values)
    end
  end

  def set_time_zone
    Time.zone = (current_user && current_user.time_zone) ? current_user.time_zone : 'Central Time (US & Canada)'
  end

  #is_read_only users should have all edit/delete links hidden, but in case we miss one or the forge URLs, this prevents most harm
  def exclude_read_only_users
    if view_user_and_unauthorized?(params[:controller], params[:action])
      flash[:error] = "You are not authorized to perform this action"
      redirect_to :back
      return false
    end
  end

  def view_user_and_unauthorized?(controller, action)
    current_user && current_user != :false && current_user.is_read_only? && controller != 'devise/sessions' &&
      ['edit', 'new', 'create', 'update', 'delete', 'destroy', 'reset', 'complete'].include?(action)
  end

  def create_referral_url
    unless request.env["HTTP_REFERER"].blank?
      unless request.env["HTTP_REFERER"][/register|login|logout|authenticate/]
        session[:referral_url] = request.env["HTTP_REFERER"]
      end
    end
  end

  def paginate_collection(options = {}, &block)
    if block_given?
      options[:collection] = block.call
    elsif !options.include?(:collection)
      raise ArgumentError, 'You must pass a collection in the options or using a block'
    end
    default_options = { per_page: 20, page: 1 }
    options = default_options.merge options
    pages = Paginator.new self, options[:collection].size, options[:per_page], options[:page]
    first = pages.current.offset
    last = [first + options[:per_page], options[:collection].size].min
    slice = options[:collection][first...last]
    return [pages, slice]
  end

  def view_helper
    Helper.instance
  end

  def check_action_for_user
    if !@geofence.nil? && (current_account.id == @geofence.account_id || (@geofence.device_id != 0 && @geofence.device.account_id == current_account.id))
      true
    else
      false
    end
  end

  def current_group_value
    current_home_selection[:group_value]
  end

  def current_home_device
    current_home_selection[:home_device]
  end

  def current_home_selection
    initial_value = (user_session[:group_value].blank? && user_session[:home_device].blank?) ? current_user.default_home_selection : nil
    build_home_selection(initial_value)
  end

  def set_home_selection(selection)
    result = build_home_selection(selection)
    user_session[:group_value] = result[:group_value]
    user_session[:home_device] = result[:home_device]
  end

  def build_home_selection(selection)
    if selection.nil?
      if user_session[:group_value].blank? && user_session[:home_device].blank?
        { group_value: 'all', home_device: nil }
      else
        { group_value: user_session[:group_value], home_device: user_session[:home_device] }
      end
    elsif (group_id = selection.to_i) < 0
      { group_value: 'all', home_device: (-group_id).to_s }
    else
      { group_value: selection, home_device: nil }
    end
  end

  def get_date(date_inputs)
    date = ''
    date_inputs.each { |key, value|   date = date + value + ' ' }
    date = date.strip.split(' ')
    date = "#{date[2]}-#{date[0]}-#{date[1]}".to_date
    return date
  rescue
    raise "Invalid date: #{date[0]}/#{date[1]}/#{date[2]}"
  end

  def act_as_if_account
    # If they're at least super_admin and have been granted access to the requested account...
    if current_user && current_user.is_super_admin? && !params[:new_account_id].blank? && current_user.accessible_account_ids.include?(params[:new_account_id].to_i)
      session[:account_id] = params[:new_account_id].to_i
      set_home_selection(nil)
    end
    redirect_to home_path
  end

  def mobile_supported?
    devise_controller?
  end

  def set_ui_version
    session[:view_full_website] = params[:view_full_website] == 'true' if params[:view_full_website]
    redirect_to home_path
  end

  def render_confirmation_modal
    html = view_context.render "shared/confirmation_modal"
    render json: { html: html }
  end

  private

  def after_sign_out_path_for(resource_or_scope)
    (session[:view_full_website] ? set_ui_version_path(view_full_website: "true") : new_user_session_path)
  end

  def after_sign_in_path_for(resource_or_scope)
    root_path(format: params[:format])
  end

  def authorize
    unless current_user
      flash[:message] = "You're not currently logged in"
      session[:return_to] = request.fullpath
      redirect_to '/user/sign_in'
    end
  end

  # Super admin's globally administer accounts, users, and devices
  def authorize_super_admin
    if current_user.nil?
      redirect_to '/user/sign_in'
    elsif !current_user.is_super_admin?
      redirect_to controller: "/home"
    end
  end

  def authorize_device
    device = Device.find_by_id(params[:id])
    unless device && device.account == current_account
      redirect_back_or_default "/user/sign_out"
    end
  end

  def authorize_http
    result = authenticate_or_request_with_http_basic do |user_name, password|
      u = User.find_for_authentication(email: user_name) if !user_name.to_s.empty
      if !u.nil? && u.valid_password?(password)
        @current_account = u.account
      else
        redirect_to '/user/sign_in'
      end
    end
    warden.custom_failure! if performed?
  end

  def access_denied
    headers["Status"]           = "Unauthorized"
    headers["WWW-Authenticate"] = %(Basic realm="Web Password")
    render text: "Couldn't authenticate you", status: '401 Unauthorized'
    false
  end

  # Redirect to the URI stored by the most recent store_location call or
  # to the passed default.
  def redirect_back_or_default(default)
    session[:return_to] ? (redirect_to(session[:return_to]) and return) : redirect_to(default)
    session[:return_to] = nil
  end

  @@http_auth_headers = %w(X-HTTP_AUTHORIZATION HTTP_AUTHORIZATION Authorization)

  # gets BASIC auth info
  def get_auth_data
    auth_key  = @@http_auth_headers.detect { |h| request.env.key?(h) }
    auth_data = request.env[auth_key].to_s.split unless auth_key.blank?
    return auth_data && auth_data[0] == 'Basic' ? Base64.decode64(auth_data[1]).split(':')[0..1] : [nil, nil]
  end

  def set_page_title
    @page_title ||= Rails.env.production? ? 'GoTrack' : "GoTrack #{Rails.env.upcase}"
  end

  def desktop_override?
    session[:view_full_website]
  end

  def mobile?
    request.format && request.format.mobile?
  end

  def mobile_browser?
    # Commenting this to always show standard pages when accessing from mobile device (GT-213)
    # (request.env['HTTP_USER_AGENT'] || '')[/(iPhone|iPod|Android|Blackberry|BlackBerry)/]
  end

  def ios_request?
    params[:ios] || request.env["HTTP_USER_AGENT"] && request.env["HTTP_USER_AGENT"][/(iPhone|iPod|iPad)/]
  end

  def set_navigation_format
    return unless ['*/*', 'text/html'].include?(request.format)

    view_full_website = desktop_override? || !mobile_supported?

    if mobile? and view_full_website
      request.format = :html
    elsif mobile_browser? and !view_full_website
      request.format = :mobile
    end
  end

  def ensure_request_format
    # IE Back Button hack (IE sets request.format as "*/* when it should be "text/html")
    request.format = :html if request.format.nil? || (!request.format.mobile? && request.format == "*/*")
  end

  def enqueue_reading_ids_for_rg
    if @rg_readings
      ReverseGeocoder.find_all_reading_addresses(@rg_readings.map { |r| r.id if r.location.nil? && r.valid_lat_and_lng? }.compact)
    else
      @rg_readings = []
    end
  end

  def sensors_params
    params[:device][:digital_sensors_attributes] = params[:device][:digital_sensors_attributes].values if params[:device][:digital_sensors_attributes]
  end
end

class Helper
  include Singleton
  include ActionView::Helpers::DateHelper
  include ApplicationHelper
end
