require 'test_helper'

class UserTest < ActiveSupport::TestCase
  fixtures :users, :accounts

  should validate_length_of(:first_name).is_at_most(User::MAX_LENGTH[:first_name])
  should validate_length_of(:last_name).is_at_most(User::MAX_LENGTH[:first_name])

  def test_should_create_user
    assert_difference 'User.count' do
      user = create_user
      assert_not user.new_record?, "#{user.errors.full_messages.to_sentence}"
    end
  end

  def test_should_require_password
    assert_no_difference 'User.count' do
      u = create_user(password: nil)
      assert_not u.errors[:password].empty?
    end
  end

  def test_should_require_email
    assert_no_difference 'User.count' do
      u = create_user(email: nil)
      assert_not u.errors[:email].empty?
    end
  end

  def test_should_reset_password
    users(:dennis).update_attributes(password: 'new password', password_confirmation: 'new password')
    assert users(:dennis).valid_password?('new password')
  end

  def test_edit
    user = users(:dennis)
    assert_equal 'dennis', user.first_name
    assert_equal 'baldwin', user.last_name
    user.first_name = 'dennis2'
    user.last_name = 'baldwin2'
    user.password = 'testing123'
    user.password_confirmation = 'testing123'
    user.save!
    assert users(:dennis).valid_password?('testing123')
  end

  context 'account presence' do
    context 'when user is not superadmin' do
      subject { User.new(roles: [:admin]) }
      should validate_presence_of(:account)
    end

    context 'when user is superadmin' do
      subject { User.new(roles: [:superadmin]) }
      should_not validate_presence_of(:account)
    end
  end

  context 'time_zone' do
    setup do
      @u = User.new(FactoryGirl.attributes_for(:user))
    end

    should 'return Central Time if user have no account' do
      assert_equal 'Central Time (US & Canada)', @u.time_zone
    end

    context 'for user with account' do
      setup do
        account = FactoryGirl.build(:account)
        account.time_zone = 'Mountain Time (US & Canada)'
        account.save
        @u.account = account
      end

      should 'return account time_zone if user have one' do
        assert_equal 'Mountain Time (US & Canada)', @u.time_zone
      end

      should 'return time_zone after set' do
        @u.time_zone = 'Alaska'
        @u.account.reload
        assert_equal 'Alaska', @u.time_zone
      end

      should 'get time zone mapped' do
        assert_equal 'America/Denver', @u.get_time_zone
      end
    end
  end

  test 'locale should return :en for every user' do
    @u = User.new
    assert_equal :en, @u.locale
  end

  test 'per page should return 25' do
    assert_equal 25, User.per_page
  end

  context 'accessible account ids' do
    setup do
      Account.delete_all
      @a1 = FactoryGirl.create(:account)
      @a2 = FactoryGirl.create(:account)
      @u = User.new(FactoryGirl.attributes_for(:user))
      @u.account = @a1
    end

    should 'return all account ids if user is super_admin' do
      @u.roles = [:superadmin]
      accessible_accts = @u.accessible_account_ids
      assert accessible_accts.include?(@a1.id)
      assert accessible_accts.include?(@a2.id)
    end

    should 'return its account id if user is admin' do
      @u.roles = [:admin]
      accessible_accts = @u.accessible_account_ids
      assert accessible_accts.include?(@a1.id)
      assert_not accessible_accts.include?(@a2.id)
    end
  end

  context 'notify' do
    setup do
      @u = FactoryGirl.build(:user)
    end

    should 'return true if enotify account level is set' do
      @u.enotify = User::NOTIFICATIONS[:all_in_account]
      assert @u.notify_all_devices_in_account?
      assert_not @u.notify_all_devices_in_fleet?
    end

    should 'return true if enotify fleet level is set' do
      @u.enotify = User::NOTIFICATIONS[:all_in_fleet]
      assert @u.notify_all_devices_in_fleet?
      assert_not @u.notify_all_devices_in_account?
    end

    should 'return false if enotify is set as no_notify' do
      @u.enotify = User::NOTIFICATIONS[:disable]
      assert_not @u.notify_all_devices_in_fleet?
      assert_not @u.notify_all_devices_in_account?
    end
  end

  context 'assignable permissions' do
    setup do
      @u = User.new(FactoryGirl.attributes_for(:user))
    end

    should 'return lower levels than superadmin if user is superadmin' do
      @u.roles = [:superadmin]
      assert_equal [:admin, :read_write, :view_only], @u.assignable_roles
    end

    should 'return lower levels than superadmin if user is admin' do
      @u.roles = [:admin]
      assert_equal [:admin, :read_write, :view_only], @u.assignable_roles
    end

    should 'return lower levels than admin if user is a common one' do
      @u.roles = [:read_write]
      assert_equal [:read_write, :view_only], @u.assignable_roles
    end

    should 'return empty array if user is not super_admin, admin or user' do
      @u.roles = []
      assert_equal [], @u.assignable_roles
    end
  end

  context 'check for roles' do
    setup do
      @u = User.new(FactoryGirl.attributes_for(:user))
    end

    context 'for a super admin user' do
      setup do
        @u.roles = [:superadmin]
      end

      should 'return true if super_admin? function is called' do
        assert @u.is_super_admin?
      end

      should 'return true if admin? function is called' do
        assert @u.is_admin?
      end

      should 'return false if read_only? function is called' do
        assert_not @u.is_read_only?
      end
    end

    context 'for an admin user' do
      setup do
        @u.roles = [:admin]
      end

      should 'return true if super_admin? function is called' do
        assert_not @u.is_super_admin?
      end

      should 'return true if admin? function is called' do
        assert @u.is_admin?
      end

      should 'return false if read_only? function is called' do
        assert_not @u.is_read_only?
      end
    end

    context 'for a common user' do
      setup do
        @u.roles = [:read_write]
      end

      should 'return false if is_super_admin? function is called' do
        assert_not @u.is_super_admin?
      end

      should 'return false if is_admin? function is called' do
        assert_not @u.is_admin?
      end

      should 'return false if is_read_only? function is called' do
        assert_not @u.is_read_only?
      end
    end
  end

  test 'search for users should return user with admin email' do
    u = FactoryGirl.create(:user)
    assert User.search_for_users(u.email, 1).include?(u)
  end

  test 'group device ids should return ids of devices ' do
    @u = FactoryGirl.create(:user)
    GroupNotification.create(user_id: @u.id, group_id: 2330)

    Device.delete_all

    @d1 = Device.create!(name: 'D1', imei: '123123123123', group_id: 2330, thing_token: '1113')
    @d2 = Device.create!(name: 'D2', imei: '456456456456', group_id: 2330, thing_token: '1114')

    assert @u.group_devices_ids.include?(@d1.id)
    assert @u.group_devices_ids.include?(@d2.id)
  end

  context 'want_notifications_for_device?' do
    context 'user wants notifications for all devices' do
      setup do
        @user = FactoryGirl.build(:user, enotify: User::NOTIFICATIONS[:all_in_account])
        @device = FactoryGirl.build(:device)
      end

      should 'return true' do
        assert @user.want_notifications_for_device?(@device)
      end
    end

    context 'user wants notifications for all devices on some groups' do
      context 'when device is on a selected group' do
        setup do
          @user = FactoryGirl.create(:user, enotify: User::NOTIFICATIONS[:all_in_fleet])
          group = FactoryGirl.create(:group, image_value: 'image', account: @user.account)
          @device = FactoryGirl.create(:device, group: group, account: @user.account)
          FactoryGirl.create(:group_device, group: group, device: @device)
          FactoryGirl.create(:group_notification, group: group, user: @user)
        end

        should 'return true' do
          assert @user.want_notifications_for_device?(@device.reload)
        end
      end

      context 'when device is not on a group' do
        setup do
          @user = FactoryGirl.create(:user, enotify: User::NOTIFICATIONS[:all_in_fleet])
          @device = FactoryGirl.create(:device, account: @user.account)
          group = FactoryGirl.create(:group, image_value: 'image', account: @user.account)
          device2 = FactoryGirl.create(:device, group: group, account: @user.account)
          FactoryGirl.create(:group_notification, group: group, user: @user)
          FactoryGirl.create(:group_device, group: group, device: device2)
        end

        should 'return false' do
          assert_not @user.want_notifications_for_device?(@device)
        end
      end
    end

    context 'user does not want notification' do
      setup do
        @user = FactoryGirl.create(:user, enotify: User::NOTIFICATIONS[:disable])
        @device = FactoryGirl.create(:device)
      end

      should 'return false' do
        assert_not @user.want_notifications_for_device?(@device)
      end
    end
  end

  context '.for_account' do
    setup do
      @account = FactoryGirl.create(:account)

      @user1 = FactoryGirl.create(:user, account: @account)
      @user2 = FactoryGirl.create(:user, account: @account)
      FactoryGirl.create(:user)
    end

    should 'return all users for given account' do
      assert_equal([@user1, @user2], User.for_account(@account.id))
    end
  end

  context '.with_notifications_enabled' do
    setup do
      @user1 = FactoryGirl.create(:user, enotify: User::NOTIFICATIONS[:all_in_account])
      @user2 = FactoryGirl.create(:user, enotify: User::NOTIFICATIONS[:all_in_fleet])
      @user3 = FactoryGirl.create(:user, enotify: User::NOTIFICATIONS[:disable])
    end

    should 'return only users with enotify set to all_in_fleet or all_in_account' do
      users = User.with_notifications_enabled
      assert_includes(users, @user1)
      assert_includes(users, @user2)
      assert_not_includes(users, @user3)
    end
  end

  context '.trigger_account_subscribed_users_change' do
    setup do
      @user = FactoryGirl.create(:user, enotify: User::NOTIFICATIONS[:disable])
    end

    should 'clear account subscribed users cache if enotify changed' do
      Cache.expects(:clear_account_subcribed_users).with(@user.account_id).once
      @user.update_attributes({ enotify: User::NOTIFICATIONS[:all_in_account] })
    end

    should 'clear account subscribed users cache if subscribed_notifications changed' do
      Cache.expects(:clear_account_subcribed_users).with(@user.account_id).once
      @user.update_attributes({ subscribed_notifications: [:speed] })
    end

    should 'not clear account subscribed users cache if enotify did not change' do
      Cache.expects(:clear_account_subcribed_users).never
      @user.update_attributes({ first_name: 'John' })
    end
  end

  protected

  def create_user(options = {})
    User.create(FactoryGirl.attributes_for(:user).merge(options))
  end
end
