require "csv"

class ScheduledReportsController < ApplicationController
  layout 'reports'
  helper ReportsHelper
  before_filter :authorize
  before_filter :authorize_report, only: [:show, :download, :edit, :destroy, :update]

  def index
    redirect_to controller: :reports, action: :scheduled_reports
  end

  def show
    @report_data = CSV.parse(@scheduled_report.report_data)
  end

  def download
    send_data @scheduled_report.report_data,
      type: 'text/csv; charset=iso-8859-1; header=present',
      disposition: "attachment; filename=#{@scheduled_report.filename}"
  end

  def new
    attrs = report_params
    attrs[:user_id] = current_user.id
    @scheduled_report = ScheduledReport.new(attrs)
  end

  def create
    attrs = report_params
    attrs[:user_id] = current_user.id
    attrs[:report_span_value], attrs[:report_span_units] = attrs[:report_span_units].split('.')
    attrs[:report_params][:account_id] = current_account.id if attrs[:report_params].is_a?(Hash)
    @scheduled_report = ScheduledReport.new(attrs)

    if @scheduled_report.save
      flash[:success] = 'Report Created'
      redirect_to controller: :reports, action: :scheduled_reports
    else
      flash[:error] = ''
      @scheduled_report.errors.to_a.each do |error|
        flash[:error] += error + '<br />'
      end
      redirect_to action: :new
    end
  end

  def destroy
    @scheduled_report.destroy
    flash[:success] = 'Scheduled report deleted'
    redirect_to controller: :reports, action: :scheduled_reports
  end

  def edit
    if @scheduled_report.completed?
      if @scheduled_report.report_data.present?
        redirect_to action: :show, id: @scheduled_report.id
        return true
      else
        redirect_to action: :index
      end
    end
  end

  def update
    attrs = report_params
    attrs[:user_id] = current_user.id
    attrs[:report_span_value], attrs[:report_span_units] = attrs[:report_span_units].split('.')
    attrs[:report_params][:account_id] = current_account.id if attrs[:report_params].is_a?(Hash)

    if @scheduled_report.update_attributes(attrs)
      flash[:success] = 'Report saved'
      redirect_to controller: :reports, action: :scheduled_reports
    else
      flash[:error] = ''
      @scheduled_report.errors.to_a.each do |error|
        flash[:error] += error + '<br />'
      end
      redirect_to action: :edit, id: @scheduled_report.id
    end
  end

  private

  def authorize_report
    id = params[:scheduled_report].blank? ? params[:id] : params[:scheduled_report][:id]
    @scheduled_report = ScheduledReport.find_by(id: id)
    unless @scheduled_report && @scheduled_report.user_id == current_user.id
      redirect_back_or_default "/reports/scheduled_reports"
    end
  end

  def report_params
    return {} if params[:scheduled_report].nil?
    params.require(:scheduled_report).permit(
      :id,
      :report_name,
      'scheduled_for(5i)',
      'scheduled_for(4i)',
      'scheduled_for(3i)',
      'scheduled_for(2i)',
      'scheduled_for(1i)',
      :report_span_units,
      :report_type,
      :recur,
      :recur_interval,
      report_params: [:group_id, :device_id]
    )
  end
end
