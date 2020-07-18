class Api::MessagesController < Api::BaseController
  respond_to :json

  def send_messages
    result, error = RabbitMessageProducer.publish(params)

    if !!result
      render json: params, status: 200
    else
      render json: { error: error }, status: 500
    end
  end
end
