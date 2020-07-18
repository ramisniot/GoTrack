module Cache
  ACCOUNT_SUBSCRIBED_USERS_KEY = 'subscribed-users-account-%s'

  def self.fetch_account_subcribed_users(account_id)
    Rails.cache.fetch(ACCOUNT_SUBSCRIBED_USERS_KEY % account_id) { yield }
  end

  def self.clear_account_subcribed_users(account_id)
    Rails.cache.delete(ACCOUNT_SUBSCRIBED_USERS_KEY % account_id)
  end
end
