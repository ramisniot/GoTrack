require 'test_helper'

class ApplicationControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  
  context 'render_confirmation_modal' do
    should 'return the confirmation modal html' do
      get :render_confirmation_modal
      assert_response :success
    end
  end
end
