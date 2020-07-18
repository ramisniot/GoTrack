class GeofencesController < ApplicationController
  before_filter :authorize
  before_filter :load_colors, only: [:new, :create, :edit, :update]
  before_filter :load_sort_parameter, :only => [:index]
  before_filter :find_geofence, only: [:edit, :update]

  SORTABLE_COLUMNS = %w[name account_id address radius]

  def index
    device_id_clause  = "device_id IN (#{current_account.device_ids.join(',')})" unless current_account.device_ids.empty?
    group_id_clause   = "group_id  IN (#{current_account.group_ids.join(',')})"  unless current_account.group_ids.empty?
    account_id_clause = "account_id = #{current_account.id}"
    conditions = [device_id_clause, group_id_clause, account_id_clause].reject(&:nil?).join(' OR ')
    order = session[:sort].to_s.blank? ? '' : session[:sort].gsub(/_r$/, ' DESC')
    scope = ::Geofence.where(conditions).order(order)
    @geofences = scope.paginate(:per_page => @per_page, :page => (params[:page] || 1))
    @geofence_count = scope.count

    respond_to do |format|
      format.html
      format.json { render json: ApiResponse::Success.new({record_count: @geofence_count, geofences: @geofences}).render_message}
      format.xml { render xml: ApiResponse::Success.new({record_count: @geofence_count, geofences: @geofences}).render_message}
    end
  end

  def show
    @geofence = Geofence.where(id: params[:id]).first
    respond_to do |format|
      if @geofence
        format.json {render json: ApiResponse::Success.new({geofence: @geofence}).render_message}
        format.xml {render xml: ApiResponse::Success.new({geofence: @geofence}).render_message}
      else
        format.json {render json: ApiResponse::Fail.new('The selected geofence does not exist').render_message}
        format.xml {render xml: ApiResponse::Fail.new('The selected geofence does not exist').render_message}
      end
    end
  end

  def new
    flash.now[:error] = 'Only Admin users can create Locations' unless current_user.is_admin?

    @devices = current_account.devices
    @geofence = ::Geofence.new geofence_params(params[:geofence])
    @geofence.device = current_account.devices.find_by_id(params[:device_id]) if params[:device_id]

    if params[:latitude] && params[:longitude]
      @geofence.address = "#{params[:latitude]},#{params[:longitude]}"
      @geofence.latitude = params[:latitude]
      @geofence.longitude = params[:longitude]
    end

    @groups = current_account.groups
    session[:back] = request.env['HTTP_REFERER']
  end

  def create
    if current_user.is_admin?
      success_message=nil
      error_message='Location not created'
      back_path=nil
      params[:geofence][:radius] = ::Geofence::M_TO_KM.key(params[:geofence][:radius].to_f).to_s if params[:geofence][:measure_unit].to_i == 1
      params[:geofence].delete(:measure_unit)
      account_id = params[:geofence].delete(:account_id) if params[:geofence].include?(:account_id)
      par = fix_params_for_account_level params
      par[:polygonal] = (par[:polygonal] == 'true')
      @geofence = ::Geofence.new geofence_params(par[:geofence])
      @geofence.account_id = account_id
      respond_to do |format|
        if @geofence.save
          format.html do
            flash[:success] = success_message || "#{@geofence.name} location created"
            redirect_to (back_path || session[:back] || geofences_path)
            session[:back] = nil
          end
          format.json {render json: ApiResponse::Success.new({geofence: @geofence}).render_message}
          format.xml {render xml: ApiResponse::Success.new({geofence: @geofence}).render_message}
        else
          format.html do
            flash[:error] = error_message || @geofence.errors[:base].first || 'Location not created'
            @devices = current_account.devices
            @groups = current_account.groups
            render :new
          end
          format.json {render json: ApiResponse::Fail.new(error_message, @geofence.errors.messages).render_message}
          format.xml {render xml: ApiResponse::Fail.new(error_message, @geofence.errors.messages).render_message}
        end
      end
    else
      @geofence = Geofence.new
      @devices = current_account.provisioned_devices
      flash.now[:error] = 'Only Admin users can create Locations'
      render :new
    end
  end

  def edit
    @devices = current_account.devices
    @groups = current_account.groups

    unless @geofence && check_action_for_geofence
      flash[:error] = 'Invalid action.'
      redirect_to :back
      return
    end
    session[:back] = request.env['HTTP_REFERER']
  end

  def update(success_message=nil, error_message=nil, back_path=nil)
    params[:geofence][:radius] = ::Geofence::M_TO_KM.key(params[:geofence][:radius].to_f).to_s if params[:geofence][:measure_unit].to_i == 1
    params[:geofence].delete(:measure_unit)
    account_id = params[:geofence].delete(:account_id) if params[:geofence].include?(:account_id)

    if @geofence && check_action_for_geofence
      par = fix_params_for_account_level params
      par[:polygonal] = (par[:polygonal] == 'true')
      @geofence.attributes = geofence_params(par[:geofence])
      @geofence.account_id = account_id
      respond_to do |format|
        if @geofence.save
          format.html do
            flash[:success] = success_message || "#{@geofence.name} was updated successfully"
            redirect_to (back_path ||session[:back] || geofences_path)
            session[:back] = nil
          end
          format.json {render json: ApiResponse::Success.new({geofence: @geofence}).render_message}
          format.xml {render xml: ApiResponse::Success.new({geofence: @geofence}).render_message}
        else
          format.html do
            @devices = current_account.devices
            @groups = current_account.groups
            flash[:error] = error_message || @geofence.errors[:base].first || "#{@geofence.name} location not updated"
            render :edit
          end
          format.json {render json: ApiResponse::Fail.new(error_message, @geofence.errors.messages).render_message}
          format.xml {render xml: ApiResponse::Fail.new(error_message, @geofence.errors.messages).render_message}
        end
      end
    else
      flash[:error] = t(:invalid_action)
      redirect_to :back
    end
  end

  def destroy
    @geofence = ::Geofence.where(['geofences.id = ? AND account_id = ?', params[:id], current_account[:id]]).includes('device').first
    respond_to do |format|
      error_message = 'Invalid action' unless @geofence && check_action_for_geofence
      if !error_message && @geofence.destroy
        format.html do
          flash[:success] = "#{@geofence.name} location deleted"
          redirect_to :back
        end
        format.json { render json: ApiResponse::Success.new.render_message }
        format.xml { render xml: ApiResponse::Success.new.render_message }
      else
        format.html do
          flash[:error] = error_message || @geofence.errors[:base].first || "#{@geofence.name} location not deleted"
          redirect_to :back
        end
        format.json { render json: ApiResponse::Fail.new(error_message || @geofence.errors.messages).render_message }
        format.xml { render xml: ApiResponse::Fail.new(error_message || @geofence.errors.messages).render_message }
      end
    end
  end

  def for_device
    order = session[:sort].to_s.blank? ? '' : session[:sort].gsub(/_r$/, ' DESC')
    @device = current_account.devices.where(id: params[:device_id]).first

    if @device
      @geofences = @device.geofences.order(order).paginate(page: (params[:page] || 1))
      @geofence_count = @device.geofences.size
      render :index
    else
      flash.now[:error] = 'You are not allowed to see the selected device'
      redirect_to home_path
    end
  end

  protected

  def geofence_params(params) # TODO fix bad ju-ju...
    params ? params.permit(:notify_enter_exit).merge(params) : {}
  end

  def check_action_for_geofence
    !@geofence.nil? && current_user.is_admin? && (current_account.id == @geofence.account_id || (@geofence.device_id != 0 && @geofence.device.account_id == current_account.id.to_i))
  end

  def fix_params_for_account_level(par)
    par.merge({:geofence => par[:geofence].merge(if par[:radio] == '1'
                                                   {:device_id => nil, :group_id => nil}
                                                 elsif params[:radio] == '2'
                                                   {:group_id => nil}
                                                 else
                                                   {:device_id => nil}
                                                 end)})
  end

  def load_colors
    @colors = {
        'Red' => 'red',
        'Blue' => 'blue',
        'Green' => 'green',
        'Hot Pink' => '#FF69B4'
    }
  end

  def load_sort_parameter(default = 'name')
    if params[:sort].blank? && session[:sort].blank? #not asked to sort
      session[:sort] = default
    elsif !params[:sort].blank? && session[:sort] == params[:sort] #reverse the sort
      session[:sort] = params[:sort]+'_r'
    elsif !params[:sort].blank?
      session[:sort] = params[:sort]
    end

    session[:sort] = '' unless SORTABLE_COLUMNS.include?(session[:sort].to_s.gsub(/_r$/,''))
  end

  def find_geofence
    @geofence = ::Geofence.where(["geofences.id = ?", params[:id]]).includes("device").first
  end

end
