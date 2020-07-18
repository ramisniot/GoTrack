class LocationsController < ApplicationController
  before_action :authorize

  def search_readings_location
    updated_readings = Reading.by_ids_with_location(params[:reading_ids].split(',').flatten).to_a

    updated_readings.map! do |reading|
      { type: 'reading', id: reading.id, address: reading.location.format_address }
    end

    render json: { data: updated_readings }, status: :ok
  end
end
