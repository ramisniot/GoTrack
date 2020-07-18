require 'test_helper'

class AccountTest < ActiveSupport::TestCase
  should validate_numericality_of(:default_map_latitude).is_less_than_or_equal_to(90)
  should validate_numericality_of(:default_map_latitude).is_greater_than_or_equal_to(-90)
  should validate_numericality_of(:default_map_latitude).allow_nil

  should validate_numericality_of(:default_map_longitude).is_less_than_or_equal_to(180)
  should validate_numericality_of(:default_map_longitude).is_greater_than_or_equal_to(-180)
  should validate_numericality_of(:default_map_longitude).allow_nil

  test 'per_page should return 25' do
    assert_equal 25, Account.per_page
  end

  context 'outside_working_hours' do
    setup do
      @a = Account.create!(zip: '12345', company: 'RSC', subdomain: 'rsc', is_verified: true, speed_threshold: 75)
    end

    should 'return true if account does not have any working hours set' do
      @a.stubs(working_hours: ['', '', '', '', '', '', '',
                               '', '', '', '', '', '', ''])
      assert @a.outside_working_hours?(Time.utc(2013, 2, 10))
    end

    should 'return true if the account\'s working hours have no start' do
      @a.stubs(working_hours: ['', '', '', '', '', '', '',
                               '2000', '2000', '2000', '2000', '2000', '2000', '2000'])
      assert @a.outside_working_hours?(Time.utc(2013, 2, 10))
    end

    should 'return true if the account\'s working hours have no end' do
      @a.stubs(working_hours: ['0800', '0800', '0800', '0800', '0800', '0800', '0800',
                               '', '', '', '', '', '', ''])
      assert @a.outside_working_hours?(Time.utc(2013, 2, 10))
    end

    should 'return true if datetime is into working hours' do
      @a.stubs(working_hours: ['2000', '2000', '2000', '2000', '2000', '2000', '2000',
                               '2000', '2000', '2000', '2000', '2000', '2000', '2000'])
      assert @a.outside_working_hours?(Time.utc(2013, 2, 10))
    end

    context 'using timezone' do
      setup do
        @a.stubs(working_hours: ['0800', '0800', '0800', '0800', '0800', '0800', '0800',
                                 '2000', '2000', '2000', '2000', '2000', '2000', '2000'])
      end

      should 'return true if datetime is inside working hours with default timezone' do
        assert @a.outside_working_hours?(Time.utc(2013, 2, 10, 3))
      end

      should 'return false if datetime is inside working hours with different timezone' do
        @a.update_attributes!(time_zone: 'Hawaii')
        assert_not @a.outside_working_hours?(Time.utc(2013, 2, 10, 2))
      end
    end

    should 'return false if datetime is outside working hours' do
      @a.stubs(working_hours: ['0000', '0000', '0000', '0000', '0000', '0000', '0000',
                               '0000', '0000', '0000', '0000', '0000', '0000', '0000'])
      assert @a.outside_working_hours?(Time.utc(2013, 2, 10))
    end
  end

  context 'template_by_address' do
    setup do
      @account = FactoryGirl.create(:account)
    end

    context 'a template for the given address exists' do
      setup do
        @sensor_template = FactoryGirl.create(:sensor_template, account: @account, address: 1)
        @sensor_template_by_address = @account.template_by_address(1)
      end

      should 'return sensor template' do
        assert_equal @sensor_template, @sensor_template_by_address
      end
    end

    context 'a template for the given address does not exist' do
      should 'return nil' do
        assert_nil @account.template_by_address(1)
      end
    end
  end

  context 'sync_and_save' do
    setup do
      @company = 'New Co'
      @account = FactoryGirl.create(:account, company: @company, subdomain: @company)
    end

    context 'when successfully post to QIOT' do
      setup do
        @collection_token = 'token'
        QiotApi.stubs(:create_collection).returns(success: true, data: { 'collection': { 'collection_token': @collection_token } })
      end

      should 'return no errors' do
        errors = @account.sync_and_save(@company)
        assert errors.empty?
      end

      should 'create account with collection_token' do
        errors = @account.sync_and_save(@company)
        assert Account.find_by(collection_token: @collection_token)
      end
    end

    context 'when post to QIOT fails' do
      setup do
        @error = 'QIOT post error'
        QiotApi.stubs(:create_collection).returns(success: false, error: @error)
      end

      should 'returns an error' do
        errors = @account.sync_and_save(@company)
        assert_equal errors.first, 'QIOT post error'
      end
    end

    context 'when account is invalid' do
      setup do
        @account.company = ''
        @collection_token = 'token'
        QiotApi.stubs(:create_collection).returns(success: true, data: { 'collection': { 'collection_token': @collection_token } })
      end

      should 'return an error' do
        errors = @account.sync_and_save(@company)
        assert errors.any?
      end
    end
  end

  context 'sync_and_update' do
    setup do
      @collection_token = 'token'
      @account = FactoryGirl.create(:account, company: 'New Co', subdomain: 'newco', collection_token: @collection_token)
      @account.save!
      @account_params = { company: 'New name', subdomain: 'newco' }
    end

    context 'when successfully patch to QIOT' do
      setup do
        QiotApi.stubs(:update_collection).returns(success: true, data: { 'collection': { 'collection_token': @collection_token } })
      end

      should 'return no errors' do
        errors = @account.sync_and_update(@account_params)
        assert errors.empty?
      end

      should 'updates account name' do
        errors = @account.sync_and_update(@account_params)
        assert_equal Account.find_by(collection_token: @collection_token).company, @account_params[:company]
      end
    end

    context 'when post to QIOT fails' do
      setup do
        @error = 'QIOT post error'
        QiotApi.stubs(:update_collection).returns(success: false, error: @error)
      end

      should 'returns an error' do
        errors = @account.sync_and_update(@account_params)
        assert_equal errors.first, @error
      end
    end

    context 'when provided attrs are invalid' do
      setup do
        @account_params = { company: nil, subdomain: nil }
        QiotApi.stubs(:update_collection).returns(success: true, data: { 'collection': { 'collection_token': @collection_token } })
      end

      should 'return an error' do
        errors = @account.sync_and_update(@account_params)
        assert errors.any?
      end
    end
  end

  context 'sync_and_delete' do
    setup do
      @collection_token = 'token'
      @account = FactoryGirl.create(:account, company: 'New Co', subdomain: 'newco')
      @account.save!
    end

    context 'when successfully patch to QIOT' do
      setup do
        QiotApi.stubs(:delete_collection).returns(success: true)
      end

      should 'return no errors' do
        errors = @account.sync_and_delete
        assert errors.empty?
      end

      should 'deletes account' do
        errors = @account.sync_and_delete
        assert_nil Account.find_by(collection_token: @collection_token)
      end
    end

    context 'when post to QIOT fails' do
      setup do
        @error = 'QIOT post error'
        QiotApi.stubs(:delete_collection).returns(success: false, error: @error)
      end

      should 'returns an error' do
        errors = @account.sync_and_delete
        assert_equal errors.first, @error
      end
    end
  end

  context '#default_map_center' do
    setup do
      @account = FactoryGirl.build(:account,
        default_map_latitude: 39.125,
        default_map_longitude: -94.551)
    end

    should 'return nil if default_map_latitude is nil' do
      @account.default_map_latitude = nil
      assert_nil(@account.default_map_center)
    end

    should 'return nil if default_map_longitude is nil' do
      @account.default_map_longitude = nil
      assert_nil(@account.default_map_center)
    end

    should 'return hash with lat and lng if both are not nil' do
      expected_map_center = {
        lat: @account.default_map_latitude,
        lng: @account.default_map_longitude
      }

      assert_equal(expected_map_center, @account.default_map_center)
    end
  end

  context 'clear_devices_from_cache' do
    setup do
      @account = FactoryGirl.create(:account)
      @device1 = FactoryGirl.create(:device,account: @account)
      @device2 = FactoryGirl.create(:device,account: @account)
    end

    should 'call clear_device_from_cache for each associated device' do
      @account.owned_devices.each{|device| device.expects(:clear_device_from_cache).returns(true)}

      @account.update_attributes(company: 'test-clear-devices')
    end

  end

  # TODO revisit digital sensor support
  # context 'devices_with_sensor_support' do
  #   setup do
  #     @account = FactoryGirl.create(:account)
  #     @device = FactoryGirl.create(:device, account: @account, gateway_name: 'calamp', device_type: 'ttu2830')
  #     @device2 = FactoryGirl.create(:device, account: @account, gateway_name: 'calamp', device_type: 'ttu2830')
  #     FactoryGirl.create(:device,  account: @account)
  #   end
  #
  #   should 'list only devices with sensors' do
  #     assert_equal [@device, @device2], @account.devices_with_sensor_support
  #   end
  # end
end
