require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  context '.standard_date_and_time' do
    setup do
      @datetime = DateTime.new(2001, 2, 3, 4, 5, 6)
      @user = FactoryGirl.build(:user)
    end

    should 'return date and time string' do
      assert_equal("02-Feb-2001 04:05 AM", standard_date_and_time(@datetime))
    end
  end

  context '.standard_date' do
    setup do
      @datetime = DateTime.new(2001, 2, 3, 4, 5, 6)
      @user = FactoryGirl.build(:user)
    end

    should 'return date string when date is given' do
      assert_equal("02-Feb-2001", standard_date(@datetime))
    end

    should 'return &nbsp when date is not given' do
      assert_equal("&nbsp;", standard_date(nil))
    end
  end

  context '.standard_time' do
    setup do
      @datetime = DateTime.new(2001, 2, 3, 4, 5, 6)
      @user = FactoryGirl.build(:user)
    end

    should 'return time string' do
      assert_equal("04:05 AM", standard_time(@datetime))
    end
  end

  context '.standard_full_datetime' do
    setup do
      @datetime = DateTime.new(2001, 2, 3, 4, 5, 6)
      @user = FactoryGirl.build(:user)
    end

    should 'return datetime string' do
      assert_equal("02-Feb-2001 04:05 AM", standard_full_datetime(@datetime))
    end
  end

  context '.standard_duration' do
    should 'return duration given, in hours and minutes format' do
      assert_equal('02h:30m', standard_duration(150))
    end
  end

  context '.standard_location' do
    setup do
      @user = FactoryGirl.build(:user)
    end

    context 'no_link attribute as false' do
      context 'exit geofence event' do
        setup do
          @reading_exit_geo = FactoryGirl.create(:reading_geofence_exit)
          @device = @reading_exit_geo.device
        end

        should 'return geofence location' do
          @user = nil
          assert_match(/.*id=\"geocode_#{@reading_exit_geo.id}\">20 NW Chipman Rd, Dallas TX.*/, standard_location(@device, @reading_exit_geo, false))
        end
      end

      context 'enter geofence event' do
        setup do
          @reading_enter_geo = FactoryGirl.create(:reading_geofence_enter)
          @device = @reading_enter_geo.device
        end

        should 'return a link to geofence' do
          assert_match(/.*View this location.* href=.*id=\"geocode_#{@reading_enter_geo.id}\">20 NW Chipman Rd, Dallas TX.*/, standard_location(@device, @reading_enter_geo, false))
        end
      end
    end

    context 'no_link attribute as true' do
      context 'enter geofence event' do
        setup do
          @reading_enter_geo = FactoryGirl.build(:reading_geofence_enter)
          @device = @reading_enter_geo.device
        end

        should 'return geofence name' do
          assert_equal("<div>Downtown</div>", standard_location(@device, @reading_enter_geo, true))
        end
      end

      context 'ignition event' do
        setup do
          @reading_ignition = FactoryGirl.create(:reading_a_1)
          @device = @reading_ignition.device
        end

        should 'return location address' do
          assert_match(/<div>.*class=\"geocode\" id=\"geocode_#{@reading_ignition.id}\">Getting Address...*/, standard_location(@device, @reading_ignition, true))
        end
      end

      context 'current user is not read_only' do
        context 'mobile view' do
          setup do
            @reading_enter_geo = FactoryGirl.build(:reading_geofence_enter)
            @device = @reading_enter_geo.device
          end

          should 'return geofence name' do
            assert_equal("<div>Downtown</div>", standard_location(@device, @reading_enter_geo, false, true))
          end
        end

        context 'desktop view' do
          setup do
            @reading_ignition = FactoryGirl.create(:reading_a_1)
            @device = @reading_ignition.device
          end

          should 'return link to geofence location' do
            assert_match(/.*href=.*id=\"geocode_#{@reading_ignition.id}.*/, standard_location(@device, @reading_ignition, false, false))
          end
        end
      end

      context 'mobile view' do
        setup do
          @reading_ignition = FactoryGirl.create(:reading_a_1)
          @device = @reading_ignition.device
        end

        should 'return location' do
          assert_equal("<div>Getting Address...</div>", standard_location(@device, @reading_ignition, false, true))
        end
      end
    end

    context 'nil reading' do
      setup do
        @device = FactoryGirl.build(:device)
      end

      should 'return GPS Not Available' do
        assert_equal('<div>GPS Not Available</div>', standard_location(@device, nil))
      end
    end
  end

  context '.standard_location_text' do
    context 'reading is nil' do
      setup do
        @device = FactoryGirl.build(:device)
      end

      should 'return GPS Not Available' do
        assert_equal('GPS Not Available', standard_location_text(@device, nil))
      end
    end

    context 'reading does not have geofence' do
      setup do
        @reading = FactoryGirl.create(:reading_location)
        @device = @reading.device
      end

      should 'return short address of reading' do
        assert_equal(@reading.short_address, standard_location_text(@device, @reading))
      end
    end

    context 'reading has geofence' do
      setup do
        @reading_geofence = FactoryGirl.create(:reading_geofence_enter)
        @device = @reading_geofence.device
      end

      should 'return geofence name and short address of reading' do
        assert_equal("#{@reading_geofence.geofence.name}; #{@reading_geofence.short_address}", standard_location_text(@device, @reading_geofence))
      end
    end
  end

  context '.display_result_count' do
    context 'total count < per page' do
      should 'return result count' do
        total_count = 3
        per_page = 5
        assert_equal("Displaying 1 - #{total_count} of #{total_count}", display_result_count(params[:page].to_i, total_count, per_page))
      end
    end

    context 'total count < per_page * page' do
      should 'return result count' do
        page = 3
        total_count = 4
        per_page = 2
        assert_equal("Displaying 5 - 4 of 4", display_result_count(page, total_count, per_page))
      end
    end

    context 'total count > per_page * page' do
      should 'return result count' do
        page = 3
        total_count = 8
        per_page = 2
        assert_equal("Displaying 5 - 6 of 8", display_result_count(page, total_count, per_page))
      end
    end
  end

  context '.display_local_dt' do
    setup do
      @user = FactoryGirl.build(:user)
      @date_time = DateTime.new(2001, 2, 3, 4, 5, 6)
    end

    should 'display local date-time' do
      assert_equal('02-02-2001 22:05 CST', display_local_dt(@date_time))
    end
  end

  context '.reading_js' do
    setup do
      @user = FactoryGirl.build(:user)
      @reading = FactoryGirl.create(:reading_geofence_enter)
    end

    context 'reading has data' do
      context 'show direction and phone number' do
        should 'return complete reading' do
          expected = {
            id: @reading.id,
            lat: '1.2',
            lng: '1.4',
            speed: 80,
            geofence: 'entering Downtown',
            address: '20 NW Chipman Rd, Dallas TX',
            note: nil,
            event: 'Entergeofen 20',
            dt: '02-Feb-2001 04:05 AM',
            full_dt: '02-Feb-2001 04:05 AM',
            direction: 89.7,
            device_phone_number: nil
          }
          assert_equal(expected.to_json, reading_js(@reading, true, true))
        end
      end
    end

    context 'empty reading' do
      should 'return empty json' do
        assert_equal('{}', reading_js(nil, false, false))
      end
    end
  end

  context '.full_device_status' do
    setup do
      @device = FactoryGirl.build(:device)
    end

    should 'return "-" if device has not last_gps_reading' do
      assert_equal('-', full_device_status(@device))
    end

    context 'for device with last_gps_reading' do
      setup do
        @reading = FactoryGirl.build(:reading_update_recent_event2)
        @device.last_gps_reading = @reading
      end

      context 'when ignition is nil' do
        setup do
          @reading.ignition = nil
        end

        should 'return html for stop report' do
          assert_match(/<a.*title="View stop report".*>Stopped<\/a>/, full_device_status(@device))
        end
      end

      context 'when ignition is true' do
        setup do
          @reading.ignition = true
        end

        context 'speed equal to 0' do
          should 'return html for idle report' do
            assert_match(/<a.*title="View idle report".*>Idle<\/a>/, full_device_status(@device))
          end
        end

        context 'speed greater than 0' do
          should 'return html for moving report' do
            @reading.speed = 50
            assert_match(/<a.*title="View all readings".*>Moving.*50.*<\/a>/, full_device_status(@device))
          end
        end
      end

      context 'with digital sensor reading' do
        setup do
          FactoryGirl.build(:digital_sensor_reading, value: true, reading: @reading)
        end

        should 'return digital sensor status' do
          assert_match(/<a.*>.*<\/a> \/ <a.*title="View digital sensors".*>Digital Sensor \(High\)<\/a>/, full_device_status(@device))
        end
      end
    end
  end

  context '.render_icon' do
    should 'return correct icon for id = 2' do
      assert_equal(image_tag('icons/red_small.png', class: 'sel_icon__icon'), render_icon(2))
    end

    should 'return correct icon for id = 3' do
      assert_equal(image_tag('icons/green_small.png', class: 'sel_icon__icon'), render_icon(3))
    end

    should 'return correct icon for id = 4' do
      assert_equal(image_tag('icons/yellow_small.png', class: 'sel_icon__icon'), render_icon(4))
    end

    should 'return correct icon for id = 5' do
      assert_equal(image_tag('icons/purple_small.png', class: 'sel_icon__icon'), render_icon(5))
    end

    should 'return correct icon for id = 6' do
      assert_equal(image_tag('icons/dark_blue_small.png', class: 'sel_icon__icon'), render_icon(6))
    end

    should 'return correct icon for id = 7' do
      assert_equal(image_tag('icons/grey_small.png', class: 'sel_icon__icon'), render_icon(7))
    end

    should 'return correct icon for id = 8' do
      assert_equal(image_tag('icons/orange_small.png', class: 'sel_icon__icon'), render_icon(8))
    end
  end

  context '.get_location_address' do
    context 'reading does not have location' do
      setup do
        @reading = FactoryGirl.create(:reading_update_recent_event1)
      end
      should 'return Getting Address' do
        assert_match(/<div class="geocode" id="geocode_#{@reading.id}">Getting Address.*/, get_location_address(@reading))
      end
    end

    context 'reading has location' do
      setup do
        @reading_location = FactoryGirl.create(:reading_location)
      end
      should 'return reading address' do
        assert_equal(%{<div class="geocode" id="geocode_#{@reading_location.id}">20 NW Chipman Rd, Dallas TX</div>}, get_location_address(@reading_location))
      end
    end
  end

  context '.extract_location' do
    context 'reading has an associated location' do
      setup do
        @reading_location = FactoryGirl.build(:reading_location)
      end

      should 'return location format_address' do
        assert_equal('20 NW Chipman Rd, Dallas TX', extract_location(@reading_location))
      end
    end

    context 'reading does not have an associated location' do
      setup do
        @reading = FactoryGirl.build(:reading)
      end

      should 'return Getting address' do
        assert_equal('Getting Address...', extract_location(@reading))
      end
    end
  end

  context '.button_to_function' do
    should 'return input type button' do
      expected = %{<input class=\"button\" type=\"button\" value=\"Zoom Map to Address\" onclick=\";\" />}
      assert_equal(expected, button_to_function('Zoom Map to Address', nil, class: 'button'))
    end
  end

  context '.default_map_center_json' do
    setup do
      @account = FactoryGirl.build(:account)
    end

    context 'when current_account does not have a default map center' do
      should 'return Kansas City lat & lng as json' do
        expected_map_center = {
          lat: ApplicationHelper::KANSAS_CITY_LAT,
          lng: ApplicationHelper::KANSAS_CITY_LNG
        }.to_json

        assert_equal(expected_map_center, default_map_center_json)
      end
    end

    context 'when current_account has a default map center' do
      setup do
        @account.default_map_latitude = 39.125
        @account.default_map_longitude = -94.551
      end

      should 'returns this as json' do
        expected_map_center = {
          lat: @account.default_map_latitude,
          lng: @account.default_map_longitude
        }.to_json
        assert_equal(expected_map_center, default_map_center_json)
      end
    end
  end

  private

  def current_account
    @account
  end

  def current_user
    @user
  end
end
