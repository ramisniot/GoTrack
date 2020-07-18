require 'test_helper'

class HomeControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  context 'vehicle_status' do
    setup do
      user = FactoryGirl.create(:test_superadmin)
      group = FactoryGirl.create(:group, account: user.account)
      FactoryGirl.create(:device, account: user.account)
      FactoryGirl.create(:device, account: user.account, group: group)

      sign_in(user)
    end

    should 'render the correct view for mobile' do
      get :vehicle_status, { format: 'mobile' }
      assert_response :success
      assert_template 'vehicle_status'
    end

    should 'render the correct view for desktop' do
      get :vehicle_status, { format: 'html' }
      assert_response :success
      assert_template 'vehicle_status'
    end
  end
end
