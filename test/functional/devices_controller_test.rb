require 'test_helper'

class DevicesControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  fixtures :users, :devices, :accounts, :groups, :device_profiles

  module RequestExtensions
    def server_name
      'helo'
    end

    def path_info
      'adsf'
    end
  end

  def setup
    @request.extend(RequestExtensions)
    QiotApi.stubs(:update_thing).returns(success: true)
    RabbitMessageProducer.stubs(:publish_forget_device).returns(success: true)
  end

  def test_index
    sign_in users(:dennis)
    get :index, {}
    assert_response :success
  end

  def test_index_with_group_selection
    sign_in users(:dennis)
    get :index, { group_id: 1 }
    devices = assigns(:devices)
    assert_equal 2, devices.size
  end

  def test_index_notauthorized
    get :index
    assert_redirected_to '/user/sign_in'
  end

  def test_update
    sign_in users(:dennis)
    put :update, { id: '1', device: { name: 'qwerty', imei: '000000' } }
    assert_equal devices(:device1).name, 'qwerty'
    assert_equal devices(:device1).imei, '000000'
    assert_redirected_to controller: 'devices'
  end

  def test_update_for_uniqueness_of_imei
    sign_in users(:dennis)
    put :update, { id: '1', device: { name: 'qwerty', imei: '551211' } }
    assert_match /Imei must be unique; this one is already in use/, flash[:error]
  end

  def test_edit_post_unauthorized
    sign_in users(:nick)
    get :edit, { id: '1' }
    assert_response 302
  end

  def test_edit_get
    sign_in users(:dennis)
    get :edit, { id: '1' }
    assert_equal devices(:device1).name, 'device 1'
    assert_equal devices(:device1).imei, '1234'
    assert_response :success
  end

  def test_edit_get_unauthorized
    sign_in users(:nick)
    get :edit, { id: '1' }
    assert_response 302
  end

  def test_admin_delete_device
    sign_in users(:dennis)
    delete :destroy, { id: '1' }
    assert_redirected_to controller: 'devices'
    assert_equal 2, devices(:device1).provision_status_id
  end

  def test_non_admin_delete_device
    sign_in users(:demo)
    delete :destroy, { id: '1' }
    assert_redirected_to controller: 'devices'
    assert_equal flash[:error], 'Invalid action'
    assert_equal 1, devices(:device1).provision_status_id
  end

  def test_delete_unauthorized
    sign_in users(:nick)
    delete :destroy, { id: '1' }
    assert_response 302
    assert_not_equal devices(:device1).provision_status_id, 2
  end

  def test_choose_mt
    sign_in users(:dennis)
    post :choose_mt, { imei: '33333', name: 'device 1' }
    assert_redirected_to controller: 'devices'
    assert_equal devices(:device5).provision_status_id, 1
    assert_equal devices(:device5).account_id, 1
  end

  def test_choose_new_mt
    sign_in users(:dennis)
    post :choose_mt, { imei: '314159', name: 'new device', thing_token: 'qwgf1111' }
    assert_redirected_to controller: 'devices'
    new_device = Device.find_by(imei: '314159')
    assert_equal 1, new_device.provision_status_id
    assert_equal 1, new_device.account_id
    assert_equal 6480, new_device.offline_threshold
  end

  def test_choose_already_provisioned
    sign_in users(:dennis)
    post :choose_mt, { imei: '1234' }
    assert_equal flash[:error], 'This device has already been added'
    assert_response :success
  end

  def test_search_devices
    sign_in users(:dennis)
    get :search_devices, { device_search: 'device' }
    assert_response :success
  end

  context 'on update' do
    setup do
      user = FactoryGirl.create(:user)
      sign_in(user)
      @device = FactoryGirl.create(:device, account: user.account)
    end

    context 'device without sensors' do
      setup do
        @sensors = {
          '0' => { id: '', name: 'Sensor1', high_label: 'high_label', low_label: 'low_label', address: '1', notification_type: '0' },
          '1' => { id: '', name: 'Sensor2', high_label: 'high_label', low_label: 'low_label', address: '2', notification_type: '1' }
        }
        @update_attributes = { id: @device.id, device: { name: 'my device', imei: @device.imei, digital_sensors_attributes: @sensors } }
      end

      should 'create digital sensors' do
        assert_difference 'DigitalSensor.count', 2 do
          post :update, @update_attributes
        end
      end

      should 'add digital sensors' do
        post :update, @update_attributes

        device_digital_sensors = Device.find(@device.id).digital_sensors.sort_by(&:id)
        assert_equal 2, device_digital_sensors.size
        assert_hash_object @sensors['0'], device_digital_sensors[0]
        assert_hash_object @sensors['1'], device_digital_sensors[1]
      end

      should 'add sensors template' do
        post :update, @update_attributes

        account = @device.account
        assert_hash_object @sensors['0'], account.sensor_templates.where(address: 1).first
        assert_hash_object @sensors['1'], account.sensor_templates.where(address: 2).first
      end
    end

    context 'device with sensors' do
      setup do
        sensors = {
          '0' => { name: 'Sensor1', high_label: 'high_label', low_label: 'low_label', address: '1', notification_type: '0' },
          '1' => { name: 'Sensor2', high_label: 'high_label', low_label: 'low_label', address: '2', notification_type: '1' }
        }
        @device.update_attributes!(digital_sensors_attributes: sensors.values)

        @sensors2 = {
          '0' => { id: @device.sensor(1).id, name: 'Sensor3', high_label: 'high_label', low_label: 'low_label', address: '1', notification_type: '0' },
          '1' => { id: @device.sensor(2).id, name: 'Sensor4', high_label: 'high_label', low_label: 'low_label', address: '2', notification_type: '1' }
        }

        @update_attributes = { id: @device.id, device: { name: 'my device', imei: @device.imei, digital_sensors_attributes: @sensors2 } }
      end

      should 'not create digital sensors' do
        assert_no_difference 'DigitalSensor.count' do
          post :update, @update_attributes
        end
      end

      should 'update digital sensors' do
        post :update, @update_attributes
        device_digital_sensors = @device.reload.digital_sensors.sort_by(&:id)

        assert_equal 2, device_digital_sensors.size
        assert_hash_object @sensors2['0'], device_digital_sensors[0]
        assert_hash_object @sensors2['1'], device_digital_sensors[1]
      end

      should 'update to sensors templates' do
        post :update, @update_attributes

        account = @device.account
        assert_hash_object @sensors2['0'], account.sensor_templates.where(address: 1).first
        assert_hash_object @sensors2['1'], account.sensor_templates.where(address: 2).first
      end
    end
  end

  private

  def assert_hash_object(expected, sensor)
    expected.each do |key, value|
      assert_equal value, sensor.send(key).to_s if key != :id
    end
  end
end
