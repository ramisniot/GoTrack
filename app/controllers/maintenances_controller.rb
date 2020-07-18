class MaintenancesController < ApplicationController
  before_filter :authorize
  before_filter :load_devices, only: %i(new create reset)
  before_filter :find_maintenance, only: %i(show destroy complete reset)
  layout 'maintenance'

  def find_maintenance
    @maintenance = Maintenance.find_by_id(params[:id])

    unless @maintenance
      flash[:error] = " Maintenance could not be found. "
      redirect_to action: :index
    end
  end

  def load_devices
    @devices = current_account.provisioned_devices
  end

  def index
    arguments = {}
    conditions = []

    @devices_list = current_account.provisioned_devices

    if params[:device] && params[:device] != 'all'
      conditions << 'maintenances.device_id = :device_id'
      arguments[:device_id] = params[:device]
    end

    unless params[:task_desc].blank?
      conditions << "concat(' ', maintenances.description_task, ' ') ilike :task"
      arguments[:task] = "% #{params[:task_desc]} %"
    end

    unless params[:from].blank? && params[:to].blank?
      begin
        from = params[:from].to_date.strftime("%Y-%m-%d")
        to = params[:to].to_date.strftime("%Y-%m-%d")
      rescue StandardError
        flash[:error] = "From/To Invalid Date"
      end
      conditions << "scheduled_time between :from and :to"
      arguments[:from] = from
      arguments[:to] = to
    end

    if params[:status] && params[:status] != 'all'
      case params[:status].to_i
        when Maintenance::STATUS_COMPLETED
          conditions << "completed_at is not null"
        when Maintenance::STATUS_OK
          conditions << "(#{date_diff} > 10 or (maintenances.target_mileage - devices.total_mileage) > 100) and completed_at is null"
        when Maintenance::STATUS_PENDING
          conditions << "((#{date_diff} <= 10 and #{date_diff} > 1) or ((maintenances.target_mileage - devices.total_mileage) <= 100 and (maintenances.target_mileage - devices.total_mileage) > 25)) and completed_at is null"
        when Maintenance::STATUS_DUE
          conditions << "((#{date_diff} <= 1 and #{date_diff} >= 0) or ((maintenances.target_mileage - devices.total_mileage) <= 25 and (maintenances.target_mileage - devices.total_mileage) > 1)) and completed_at is null"
        when Maintenance::STATUS_PDUE
          conditions << "((#{date_diff} < 0) or (maintenances.target_mileage - devices.total_mileage < 1)) and completed_at is null"
      end
    end

    ### Provisioned devices that belongs to user account

    conditions << "devices.provision_status_id = 1 and devices.account_id = :aid"
    arguments[:aid] = current_account

    if params[:mileage] && params[:mileage] != 'all'
      conditions << "mileage = :mileage"
      arguments[:mileage] = params[:mileage]
    end

    all_conditions = conditions.join(' AND ')

    @maintenances = Maintenance.includes(:device).where(all_conditions, arguments).order('devices.created_at DESC').paginate page: params[:page], per_page: RESULT_COUNT
  end

  def new
    @maintenance = Maintenance.new(type_task: Maintenance::SCHEDULED_TYPE)
  end

  def show; end

  def create
    @maintenance = Maintenance.new(maintenance_params)
    if @maintenance.is_scheduled?
      @maintenance.mileage = nil
    else
      @maintenance.scheduled_time = nil
      @maintenance.device.update_mileage! #if @maintenance.device.total_mileage < 0 ##The mileage can be outdated!
      @maintenance.target_mileage = (@maintenance.device.total_mileage + @maintenance.mileage)
      @maintenance.device_mileage = @maintenance.device.total_mileage
    end
    if @maintenance.save
      flash[:success] = " Maintenance task was successfully created. "
      redirect_to action: :index
    else
      flash.now[:error] = ''
      @maintenance.errors.to_a.each do |error|
        flash.now[:error] += error + '<br />'
      end
      render action: :new
    end
  end

  def destroy
    if @maintenance.destroy
      flash[:success] = " Maintenance task was successfully deleted. "
      redirect_to action: :index
    else
      flash[:error] = " Error deleting Maintenance task. "
      redirect_to action: :show
    end
  end

  def reset
    if request.post?
      @maintenance.completed_at = DateTime.now
      @new_maintenance_task = Maintenance.new(maintenance_params)
      @new_maintenance_task.device = @maintenance.device
      if @new_maintenance_task.is_scheduled?
        @new_maintenance_task.mileage = nil
      else
        @new_maintenance_task.scheduled_time = nil
        @new_maintenance_task.device.update_mileage if @new_maintenance_task.device.total_mileage.negative?
        @new_maintenance_task.target_mileage = (@new_maintenance_task.device.total_mileage + @new_maintenance_task.mileage)
        @new_maintenance_task.device_mileage = @new_maintenance_task.device.total_mileage
      end
      if @maintenance.save && @new_maintenance_task.save
        flash[:success] = " Maintenance task was successfully completed. "
        redirect_to maintenance_path(@new_maintenance_task)
      else
        flash[:error] = " Error reseting Maintenance task. "
        redirect_to action: :show
      end
    end
  end

  def complete
    unless @maintenance.is_completed?
      @maintenance.completed_at = DateTime.now
      if @maintenance.save
        flash[:success] = " Maintenance task was successfully completed. "
      else
        flash[:error] = " Error completing Maintenance task. "
      end
    else
      flash[:error] = " Maintenance task was already completed. "
    end
    redirect_to action: :show
  end

  private

  def date_diff
    "maintenances.scheduled_time - current_date"
  end

  def maintenance_params
    params.require(:maintenance).permit(:device_id, :description_task, :type_task, :mileage, :scheduled_time,
                                        :alerted_at, :target_mileage, :device_mileage, :completed_at, :notified_at)
  end
end
