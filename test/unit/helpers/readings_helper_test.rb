require 'test_helper'

class ReadingsHelperTest < ActionView::TestCase
  include ApplicationHelper

  context 'hash_from_device' do
    setup do
      @device = FactoryGirl.build(:device)
      user = FactoryGirl.build(:user)
      @device_hash = hash_from_device(@device, user)
    end

    should 'return a hash' do
      assert_equal Hash, @device_hash.class
    end

    should 'return device attributes' do
      @device.attributes do |key, _|
        assert @device_hash.key?(key)
      end
    end

    should 'return methods attributes' do
      methods = [:dt, :helper_standard_location, :geofence, :address, :icon_id, :latitude, :longitude, :speed, :direction, :has_movement_alert_for_current_user, :last_gps_reading_id]

      methods.each do |key|
        assert @device_hash.key?(key)
      end
    end

    should 'return latest_state_html attribute' do
      assert @device_hash.key?(:latest_status_html)
    end

    should 'return geofence_violations attribute' do
      assert @device_hash.key?(:geofence_violations)
    end
  end

  context 'readings_for_device_js' do
    setup do
      device = FactoryGirl.create(:device)
      @readings = []
      (1..3).each do
        @readings << FactoryGirl.create(:reading, device: device)
      end
      @user = FactoryGirl.create(:user)
      @json = readings_for_device_js(@readings)
    end

    context 'integer attributes' do
      should 'set id, speed, direction attributes' do
        attributes = [:id, :speed, :direction]
        attributes.each do |attribute|
          (1...3).each do |index|
            assert_match /"#{attribute}":#{@readings[index].send(attribute)}/, @json
          end
        end
      end
    end

    context 'string attributes' do
      should 'set lat, geofence, lng attribute' do
        attributes = { lat: :latitude, geofence: :fence_description, lng: :longitude }
        attributes.each do |key, value|
          (1...3).each do |index|
            assert_match /"#{key}":"#{@readings[index].send(value)}"/, @json
          end
        end
      end

      should 'set dt attribute' do
        (1...3).each do |index|
          assert_match /"dt":"#{standard_date_and_time(@readings[index].recorded_at)}"/, @json
        end
      end

      should 'set event attribute' do
        (1...3).each do
          assert_match /"event":null/, @json
        end
      end

      should 'set device_phone_number' do
        (1...3).each do |index|
          assert_match /"device_phone_number":"#{@readings[index].device.phone_number}"/, @json
        end
      end
    end
  end

  # Used to overwrite current_user on readings_for_device_js test.
  def current_user
    @user
  end
end
