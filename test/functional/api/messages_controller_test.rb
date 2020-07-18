require 'json'
require 'test_helper'

class Api::MessagesControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  setup do
    @params = { test: 'test', thing: { thing_token: '123' } }
  end

  context 'send_messages' do
    should 'return success with the number of processed messages' do
      request.headers['HTTP_AUTHORIZATION'] = 'test-token'
      post :send_messages, @params
      assert_response :success
      json_response = JSON.parse(response.body)

      assert_equal @params[:test], json_response['test']
      assert_equal @params[:thing][:thing_token], json_response['thing']['thing_token']
    end

    should 'return 401 if not authorized' do
      request.headers['HTTP_AUTHORIZATION'] = 'invalid-token'
      post :send_messages, @params
      assert_response :unauthorized
    end
  end
end
