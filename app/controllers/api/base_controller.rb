class Api::BaseController < ApplicationController
  before_action :validate_credentials!

  def validate_credentials!
    if request.headers['HTTP_AUTHORIZATION'] != QIOT_ACCOUNT_TOKEN
      render json: { errors: 'Not authenticated' }, status: :unauthorized
    end
  end
end
