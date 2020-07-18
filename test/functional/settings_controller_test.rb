require 'test_helper'

class SettingsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  fixtures :accounts, :users

  module RequestExtensions
    def server_name
      "yoohoodilly"
    end

    def path_info
      "asdf"
    end
  end

  def setup
    @request.extend(RequestExtensions)
  end

  def test_index
    # Get the settings page
    sign_in users(:dennis)
    get :index, {}
    assert_response :success
    account = assigns(:account)
    user = assigns(:user)
    assert_equal 'Dennis Co', account.company
    assert_equal 'Central Time (US & Canada)', account.time_zone
    assert_equal 1, user.enotify

    # Post the settings
    post :submit, { company: 'New Co', notify: 1, time_zone: 'Eastern Time (US & Canada)', subscribed_notifications: [:none] }
    assert_redirected_to controller: 'settings', action: 'index'

    # Verify the settings were saved
    account = assigns(:account)
    user = assigns(:user)
    assert_equal 'New Co', account.company
    assert_equal 'Eastern Time (US & Canada)', account.time_zone
    assert_equal 1, user.enotify

    #post setting with group notification
    post :submit, { company: 'New Co', notify: 2, rad_grp1: 1, time_zone: 'Eastern Time (US & Canada)', subscribed_notifications: [:none] }
    assert_redirected_to controller: 'settings', action: 'index'

    account = assigns(:account)
    user = assigns(:user)
    assert_equal 'New Co', account.company
    assert_equal 'Eastern Time (US & Canada)', account.time_zone
    assert_equal 2, user.enotify
  end

  def test_no_permission_to_change_account_settings
    sign_in users(:demo)
    get :index, {}
    post :submit, { company: 'New Co', notify: 1, time_zone: 'Eastern Time (US & Canada)', subscribed_notifications: [:none] }
    account = assigns(:account)
    assert_equal 'Dennis Co', account.company
    assert_equal 'Central Time (US & Canada)', account.time_zone
  end

  # Test that when a user selects "No Time Zone" that the value is set to NULL in the database (this impacts the notifier daemon)
  def test_can_change_time_zone
    sign_in users(:dennis)
    get :index, {}
    post :submit, { company: 'New Co', notify: 1, time_zone: '', subscribed_notifications: [:none] }
    account = assigns(:account)
    assert_nil account.time_zone
  end

  context 'subscribed_notifications for user' do
    context 'user without subscribed_notifications' do
      setup do
        @user = FactoryGirl.create(:user, roles: [:superadmin], subscribed_notifications: [])
        sign_in @user
        post :submit, { company: 'New Co', notify: 1, time_zone: 'Eastern Time (US & Canada)', subscribed_notifications: [:offline, :speed] }
        @user.reload
      end

      should 'add offline and readings to subscribed notifications' do
        assert @user.subscribed_notifications.include?(:offline)
        assert @user.subscribed_notifications.include?(:speed)
      end
    end

    context 'user with :offline and :idling as subscribed_notifications' do
      setup do
        @user = FactoryGirl.create(:user, roles: [:superadmin], subscribed_notifications: [:offline, :idling])
        sign_in @user
        post :submit, { company: 'New Co', notify: 1, time_zone: 'Eastern Time (US & Canada)', subscribed_notifications: [:none] }
        @user.reload
      end

      should 'remove offline and readings from subscribed notifications' do
        refute @user.subscribed_notifications.include?(:offline)
        refute @user.subscribed_notifications.include?(:idling)
      end
    end

    context 'removing subscribed notifications' do
      setup do
        @user = FactoryGirl.create(:user, roles: [:superadmin], subscribed_notifications: [:sensor, :speed, :gpio])
        sign_in @user
        post :submit, { company: 'New Co', notify: 1, time_zone: 'Eastern Time (US & Canada)', subscribed_notifications: [:sensor, :speed] }
        @user.reload
      end

      should 'remove types that are not given in subscribed_notifications params' do
        assert @user.subscribed_notifications, [:sensor, :speed]
        refute @user.subscribed_notifications.include?(:gpio)
      end
    end

    context 'adding subscribed notifications' do
      setup do
        @user = FactoryGirl.create(:user, roles: [:superadmin], subscribed_notifications: [])
        sign_in @user
        post :submit, { company: 'New Co', notify: 1, time_zone: 'Eastern Time (US & Canada)', subscribed_notifications: [:sensor, :geofence] }
        @user.reload
      end

      should 'add all the types that are given in the subscribed_notification param' do
        assert @user.subscribed_notifications, [:sensor, :geofence]
        refute @user.subscribed_notifications.include?(:gpio)
        refute @user.subscribed_notifications.include?(:startup)
      end
    end
  end
end
