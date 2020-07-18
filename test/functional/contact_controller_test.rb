require 'test_helper'

class ContactControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  fixtures :users, :accounts

  module RequestExtensions
    def server_name
      "helo"
    end

    def path_info
      "adsf"
    end

    def subdomains
      ["myfleet"]
    end
  end

  def setup
    @request.extend(RequestExtensions)
    Notifier.stubs(:deliver_app_feedback).returns(true)
  end

  test 'submit' do
    sign_in users(:dennis)
    post :thanks, { feedback: "testing feedback form" }
    assert_response :success
  end

  test 'index without logging in' do
    get :index
    assert_redirected_to new_user_session_path
  end

  test 'index with logged in user' do
    sign_in users(:dennis)
    get :index
    assert_response :success
  end
end
