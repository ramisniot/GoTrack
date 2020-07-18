require 'test_helper'

class ReverseGeocoderWorkerTest < ActiveSupport::TestCase
  context '.perform' do
    setup do
      Sidekiq::Worker.clear_all
    end

    context 'when called asynchronously' do
      should 'enqueue a job' do
        assert_equal 0, ReverseGeocoderWorker.jobs.size
        ReverseGeocoderWorker.perform_async(1)
        assert_equal 1, ReverseGeocoderWorker.jobs.size

        Sidekiq::Worker.clear_all
      end
    end

    context 'when called synchronously' do
      setup do
        @reading = FactoryGirl.create(:reading)
        @success_response = { success: true, data: { city: 'city-test', postal_code: '333', country_long: 'country-test', address: 'address-test', route: 'route-test', state_long: 'state-test', county: 'county-test', state_short: 'state-abbr-test', street_number: 'street-number-test' } }
        @error_response = { success: false, error: 'error-test' }
      end

      context 'when the reverse geocoding api returns success' do
        should 'create a new location and assign it to the given reading' do
          QiotApi.stubs(:apply_reverse_geocoding)
                 .with(JSON.dump(lat: @reading.latitude, lng: @reading.longitude))
                 .once
                 .returns(@success_response)

          assert_difference -> { Location.count }, 1 do
            ReverseGeocoderWorker.new.perform(@reading.id)
          end

          reading = Reading.find_by(id: @reading.id)
          location = Location.last

          assert_equal reading.location_id, location.id
          assert_equal 'city-test', location.city
          assert_equal '333', location.zip
          assert_equal reading.latitude, location.latitude
          assert_equal reading.longitude, location.longitude
          assert_equal 'country-test', location.country
          assert_equal 'address-test', location.full_address
          assert_equal 'route-test', location.street
          assert_equal 'state-test', location.state_name
          assert_equal 'county-test', location.county
          assert_equal 'state-abbr-test', location.state_abbr
          assert_equal 'street-number-test', location.street_number
        end
      end

      context 'when the reverse geocoding api returns an error' do
        should 'raise an error' do
          QiotApi.stubs(:apply_reverse_geocoding)
                 .with(JSON.dump(lat: @reading.latitude, lng: @reading.longitude))
                 .once
                 .returns(@error_response)

          assert_nil ReverseGeocoderWorker.new.perform(@reading.id)
        end
      end
    end
  end
end
