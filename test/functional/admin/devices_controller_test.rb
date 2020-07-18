require 'test_helper'

class Admin::DevicesControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  fixtures :users, :accounts, :devices, :device_profiles

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
    QiotApi.stubs(:update_thing).returns(success: true)
    QiotApi.stubs(:create_thing).returns(success: true, data: { thing: { thing_token: 'thing_token' } })
    RabbitMessageProducer.stubs(:publish_forget_device).returns(success: true)
  end

  def test_index
    sign_in users(:dennis)
    get :index, {}
    assert_response :success
  end

  def test_devices_table
    sign_in users(:dennis)
    get :index, {}
    assert_select "table tr", 9
  end

  def test_new_device
    sign_in users(:dennis)
    get :new, {}
    assert_response :success
  end

  context 'POST create' do
    setup do
      sign_in FactoryGirl.create(:test_superadmin)
      @attrs = {
        imei: '10101',
        account_id: FactoryGirl.create(:account).id,
        thing_token: '111',
        name: 'device-name'
      }
    end

    context 'with invalid attributes' do
      setup do
        @attrs.delete(:name)
        post :create, { device: @attrs }
      end

      should 'render new template with flash error message' do
        assert_template :new
        assert_match(/Name can't be blank/, flash[:error])
      end
    end

    context 'with valid attributes' do
      setup do
        post :create, { device: @attrs }
      end

      should 'redirect to devices list with flash success message' do
        assert_redirected_to admin_devices_path
        assert_equal("#{@attrs[:name]} created successfully", flash[:success])
      end
    end

    context 'with error when syncing with QIOT' do
      setup do
        QiotApi.stubs(:create_thing).returns(success: false, error: 'Sync API error')
        post :create, { device: @attrs }
      end

      should 'render new template with flash error message' do
        assert_template :new
        assert_equal('Sync API error', flash[:error])
      end
    end
  end

  context 'POST update' do
    setup do
      sign_in FactoryGirl.create(:test_superadmin)
      @device = FactoryGirl.create(:device)

      @attrs = {
        imei: @device.imei,
        account_id: @device.account_id,
        thing_token: @device.thing_token,
        name: 'new-device-name'
      }
    end

    context 'with invalid attributes' do
      setup do
        @attrs[:name] = ''
        post :update, { id: @device.id, device: @attrs }
      end

      should 'render edit template with flash error message' do
        assert_template :edit
        assert_match(/Name can't be blank/, flash[:error])
      end
    end

    context 'with valid attributes' do
      setup do
        post :update, { id: @device.id, device: @attrs }
      end

      should 'redirect to devices list with flash success message' do
        assert_redirected_to admin_devices_path
        assert_equal("#{@attrs[:name]} updated successfully", flash[:success])
      end
    end
  end

  def test_update_device
    sign_in users(:dennis)
    post :update, { id: 1, device: { name: "my device", imei: "1234", provision_status_id: 1, account_id: 1, thing_token: '112' } }
    assert_redirected_to action: "index"
    assert_equal flash[:success], "my device updated successfully"
  end

  def test_delete_device
    sign_in users(:dennis)
    post :destroy, { id: 1 }
    assert_redirected_to action: "index"
    assert_equal flash[:success], "device 1 deleted successfully"
  end

  context 'digital sensors' do
    setup do
      @user = FactoryGirl.create(:user)
      sign_in @user
    end

    context 'on create' do
      setup do
        @sensors = {
          '0' => { id: '', name: 'Sensor1', high_label: 'high_label', low_label: 'low_label', address: '1', notification_type: '0' },
          '1' => { id: '', name: 'Sensor2', high_label: 'high_label', low_label: 'low_label', address: '2', notification_type: '1' }
        }
        post :create, { device: { name: 'my device', imei: '123456789', provision_status_id: 1, account_id: @user.account_id, digital_sensors_attributes: @sensors, thing_token: 'abcmq11134' } }
      end

      should 'add digital sensors' do
        device = Device.find_by(imei: '123456789')
        device_digital_sensors = device.digital_sensors.sort_by(&:id)
        assert_equal 2, device_digital_sensors.size
        assert_hash_object @sensors['0'], device_digital_sensors[0]
        assert_hash_object @sensors['1'], device_digital_sensors[1]
      end

      should 'add to default sensors' do
        account = @user.account
        assert_hash_object @sensors['0'], account.sensor_templates.where(address: 1).first
        assert_hash_object @sensors['1'], account.sensor_templates.where(address: 2).first
      end
    end

    context 'on update' do
      context 'Device without sensors' do
        setup do
          @device = FactoryGirl.create(:device, account: @user.account)
          @sensors = {
            '0' => { id: '', name: 'Sensor1', high_label: 'high_label', low_label: 'low_label', address: '1', notification_type: '0' },
            '1' => { id: '', name: 'Sensor2', high_label: 'high_label', low_label: 'low_label', address: '2', notification_type: '1' }
          }

          @update_params = { id: @device.id, device: { name: 'my device', imei: @device.imei, provision_status_id: 1, account_id: @user.account_id, digital_sensors_attributes: @sensors } }
        end

        should 'create digital sensors' do
          assert_difference 'DigitalSensor.count', 2 do
            post :update, @update_params
          end
        end

        should 'add digital sensors' do
          post :update, @update_params

          device_digital_sensors = Device.find(@device.id).digital_sensors.sort_by(&:id)
          assert_equal 2, device_digital_sensors.size
          assert_hash_object @sensors['0'], device_digital_sensors[0]
          assert_hash_object @sensors['1'], device_digital_sensors[1]
        end

        should 'add to sensors templates' do
          post :update, @update_params

          account = @user.account
          assert_hash_object @sensors['0'], account.sensor_templates.where(address: 1).first
          assert_hash_object @sensors['1'], account.sensor_templates.where(address: 2).first
        end
      end

      context 'device with sensors' do
        setup do
          @device = FactoryGirl.create(:device, account: @user.account)
          sensors = {
            '0' => { name: 'Sensor1', high_label: 'high_label', low_label: 'low_label', address: '1', notification_type: '0' },
            '1' => { name: 'Sensor2', high_label: 'high_label', low_label: 'low_label', address: '2', notification_type: '1' }
          }
          @device.update_attributes(digital_sensors_attributes: sensors.values)

          @sensors2 = {
            '0' => { id: @device.reload.sensor(1).id, name: 'Sensor3', high_label: 'high_label', low_label: 'low_label', address: '1', notification_type: '0' },
            '1' => { id: @device.reload.sensor(2).id, name: 'Sensor4', high_label: 'high_label', low_label: 'low_label', address: '2', notification_type: '1' }
          }

          @update_params = { id: @device.id, device: { name: 'my device', imei: @device.imei, provision_status_id: 1, account_id: @user.account_id, digital_sensors_attributes: @sensors2, thing_token: 'aqw111' } }
        end

        should 'not create digital sensors' do
          assert_no_difference 'DigitalSensor.count' do
            post :update, @update_params
          end
        end

        should 'update digital sensors' do
          post :update, @update_params

          device_digital_sensors = Device.find(@device.id).digital_sensors.sort_by(&:id)
          assert_equal 2, device_digital_sensors.size
          assert_hash_object @sensors2['0'], device_digital_sensors[0]
          assert_hash_object @sensors2['1'], device_digital_sensors[1]
        end

        should 'update to sensors templates' do
          post :update, @update_params

          account = @user.account
          assert_hash_object @sensors2['0'], account.sensor_templates.where(address: 1).first
          assert_hash_object @sensors2['1'], account.sensor_templates.where(address: 2).first
        end
      end
    end
  end

  context 'search' do
    setup do
      @account = FactoryGirl.create(:account)
      @device = FactoryGirl.create(:device, name: 'device_name', account: @account)
      sign_in users(:dennis)
    end

    context 'search without account' do
      should 'return no devices when the keyword does not match any name' do
        params = { search: { name_or_imei_cont: 'non_exists_name_like_this' } }
        post :index, params
        assert_response :success
        assert_equal [], assigns(:devices)
      end

      should 'return the devices whose name matches the keyword' do
        post :index, { search: { name_or_imei_cont: 'device_name' } }
        assert_response :success
        assert_equal [@device], assigns(:devices)
      end
    end

    context 'search with account' do
      setup do
        @account_2 = FactoryGirl.create(:account)
        @device_2 = FactoryGirl.create(:device, name: 'device_name', account: @account_2)
      end

      should 'return only the devices that belongs to the account passed' do
        post :index, { search: { account_id_eq: @account_2.id } }
        assert_response :success
        assert_equal @account_2.devices, assigns(:devices)
      end
    end
  end

  context 'clear_history' do
    setup do
      @account = FactoryGirl.create(:account)
      @device = FactoryGirl.create(:device, name: 'device_name', account: @account)
      sign_in users(:dennis)
    end

    should 'fail without device' do
      get :clear_history, id: -1
      assert_redirected_to action: 'index'
      assert_match(/No device given/, flash[:error])
    end

    should 'fail with account' do
      get :clear_history, id: @device.id
      assert_redirected_to edit_admin_device_path(id: @device.id)
      assert_match(/Device must not be assigned for history to be cleared/, flash[:error])
    end

    should 'succeed without device' do
      @device.update_attributes(account: nil)
      get :clear_history, id: @device.id
      assert_redirected_to edit_admin_device_path(id: @device.id)
      assert_match(/history cleared/, flash[:success])
    end
  end

  private

  def assert_hash_object(expected, sensor)
    expected.each do |key, value|
      assert_equal value, sensor.send(key).to_s if key != :id
    end
  end
end
