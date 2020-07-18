require 'test_helper'

class RssTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :readings, :devices

  context 'rss feed' do
    setup do
      @user = users(:dennis)
    end

    # TODO revisit XML API...
    # context 'for last' do
    #   should 'return valid xml' do
    #     get "/readings/last/#{Device.last.id}", { format: :html },
    #       'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(@user.email, 'testing')
    #     assert_response :success
    #   end
    # end
    #
    # context 'for all' do
    #   should 'return valid xml' do
    #     get "/readings/all/#{Device.last.id}", { format: :html },
    #       'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(@user.email, 'testing')
    #
    #     assert_response :success
    #   end
    # end

    context 'for public' do
      should 'return valid xml' do
        get "/readings/public/#{Account.find_by_subdomain('nick').id}", { format: :html }
        assert_response :success
      end

      should 'return empty xml if no account id sent in' do
        get "/readings/public", { format: :html }
        assert_response :success
      end
    end
  end
end
