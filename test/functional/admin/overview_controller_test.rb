require 'test_helper'

class Admin::OverviewControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  fixtures :users, :accounts, :devices, :device_profiles, :login_messages

  module RequestExtensions
    def server_name
      "helo"
    end

    def path_info
      "adsf"
    end
  end

  def setup
    @request.extend(RequestExtensions)
  end

  def test_not_logged_in
    sign_out(:user)
    get :index
    assert_redirected_to "/user/sign_in"
  end

  def test_super_admin
    sign_in users(:dennis)
    get :index, {}
    assert_response :success
  end

  def test_not_super_admin
    sign_in users(:demo)
    get :index, {}
    assert_redirected_to root_path
  end

  def test_page_contents
    sign_in users(:dennis)
    get :index, {}
    assert_select ".admin-overview-box", 3
    assert_select ".admin-overview-box:first-child .admin-overview-box__value", text: "6"
    assert_select ".admin-overview-box:nth-child(2) .admin-overview-box__value", text: "7"
    assert_select ".admin-overview-box:nth-child(3) .admin-overview-box__value", text: "7"
  end

  def test_login_message
    sign_in users(:dennis)
    get :index, {}
    assert_select 'div#login_message_content', html: "<p><strong>Hello, world.</strong></p>"

    post :set_login_message, { login_message: { message: '*One fish*' } }
    assert_redirected_to :admin_root

    get :index, {}
    assert_select 'div#login_message_content', html: "<p><em>One fish</em></p>"
  end
end
