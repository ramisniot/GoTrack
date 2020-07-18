require 'test_helper'

class MobileLoginTest < ActionDispatch::IntegrationTest
  context '/login.mobile' do
    context 'user without session' do
      setup do
        get '/login.mobile'
      end

      should 'redirect to sign_in page' do
        assert_redirected_to '/user/sign_in'
      end
    end

    # TODO revisit mobile app...
    # context 'user with session' do
    #   setup do
    #     @user = FactoryGirl.create(:user)
    #     post_via_redirect user_session_path, user: { email: @user.email, password: @user.password }, format: 'mobile'
    #     get '/login.mobile'
    #   end
    #
    #   should 'redirect to home page' do
    #     assert_redirected_to '/home/locations.mobile'
    #   end
    # end
  end
end
