require 'test_helper'

class UsersHelperTest < ActionView::TestCase
  context 'role_description' do
    should 'return Super Admin for :superadmin' do
      assert_equal 'Super Admin', role_description(:superadmin)
    end

    should 'return Admin for :admin' do
      assert_equal 'Admin', role_description(:admin)
    end

    should 'return User-R/W for :read_write' do
      assert_equal 'User-R/W', role_description(:read_write)
    end

    should 'return User-ViewOnly for :view_only' do
      assert_equal 'User-ViewOnly', role_description(:view_only)
    end
  end
end
