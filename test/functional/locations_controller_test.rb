require 'test_helper'
require 'json'

class LocationsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  context '#search_readings_location' do
    setup do
      @reading_one = FactoryGirl.create(:reading_location)

      @reading_two = FactoryGirl.create(:reading_location)

      @expected_response = {
        'data' => [
          { 'type' => 'reading', 'id' => @reading_one.id, 'address' => '20 NW Chipman Rd, Dallas TX'},
          { 'type' => 'reading', 'id' => @reading_two.id, 'address' => '20 NW Chipman Rd, Dallas TX'}
        ]
      }
    end

    context 'when unauthorized' do
      should 'redirect to sign in' do
        get :search_readings_location, { reading_ids: [ @reading_one.id, @reading_two.id ] }

        assert_redirected_to '/user/sign_in'
      end
    end

    context 'when authorized' do
      setup do
        user = FactoryGirl.create(:user)

        sign_in user
      end

      should 'return the readings with their full addresses' do
        get :search_readings_location, { reading_ids: [ @reading_one.id, @reading_two.id ] }

        locations_response = JSON.parse(@response.body)
        assert_response :success
        assert_equal @expected_response, locations_response
      end
    end
  end
end
