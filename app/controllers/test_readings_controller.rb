# The purpose of this controller is to allow superadmins
# to generate test readings for a device.
class TestReadingsController < ApplicationController
  before_filter :authorize, :verify_access

  def new
    @device = Device.find(params[:device_id])
    @lat  = @device.last_reading.try(:latitude) || 33.0625
    @lng  = @device.last_reading.try(:longitude) || -97.677068
  end

  def create
    device = Device.find(params[:device_id])

    params[:event_type] = "#{params[:event_type]}#{params[:address]}" if ['input_low_', 'input_high_'].include?(params[:event_type])

    TestReadingGenerator.new(
      latitude:   params[:latitude],
      longitude:  params[:longitude],
      device:     device,
      event_type: params[:event_type],
      speed: params[:speed],
      ignition: params[:ignition]
    )
    redirect_to action: :new
  end

  private

  def verify_access
    redirect_to home_path unless current_user.is_super_admin?
  end
end
