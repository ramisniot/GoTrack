class OneTimeReportsController < ApplicationController
  layout 'reports'
  before_filter :authorize
  before_filter :control_state_mileage_report_visibility, only: [:new, :create, :processing]

  def create
    attrs = reports_param
    attrs[:user_id] = current_user.id
    attrs[:report_params][:account_id] = current_account.id

    @report = ScheduledReport.new(attrs)
    @report.to += 1.day if @report.to
    @report.scheduled_for = @report.to
    @report.recur = false

    if @report.save
      flash[:success] = 'The report is being completed'
      redirect_to action_reports_path(action: 'scheduled_reports')
    else
      flash[:error] = @report.errors.full_messages.to_sentence
      render :new
    end
  end

  def new
  end

  private

  def control_state_mileage_report_visibility
    redirect_to reports_path unless current_user.account.show_state_mileage_report?
  end

  private

  def reports_param
    params.require(:one_time_report).permit(:report_name, 'from(3i)', 'from(2i)', 'from(1i)', 'to(3i)', 'to(2i)', 'to(1i)', :report_type, report_params: [:group_id, :device_id])
  end
end
