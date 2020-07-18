require 'test_helper'

class CacheTest < ActiveSupport::TestCase

  context '#fetch_account_subcribed_users' do
    should 'call fetch with the correct key' do
      account_id = 2
      Rails.cache.expects(:fetch).with("subscribed-users-account-#{account_id}")

      Cache.fetch_account_subcribed_users(account_id)
    end
  end

  context '#clear_account_subcribed_users' do
    should 'call fetch with the correct key' do
      account_id = 2
      Rails.cache.expects(:delete).with("subscribed-users-account-#{account_id}")

      Cache.clear_account_subcribed_users(account_id)
    end
  end
end
