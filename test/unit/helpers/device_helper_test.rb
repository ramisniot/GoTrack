require 'test_helper'

class DeviceHelperTest < ActionView::TestCase
  context 'idle_alert_threshold_options' do
    setup do
      @options = idle_alert_threshold_options(5 * 1.minutes)
    end
    should 'return correct options' do
      options = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 90, 120, 150, 180, 210,
                 240, 270, 300, 330, 360, 390, 420, 450, 480, 510, 540, 570, 600]

      options.each { |option| assert_match /<option.*value="#{option * 1.minutes}">#{option} minutes<\/option>/, @options }
    end

    should 'mark 5 as selected' do
      assert_match /<option.*selected.*value="#{5 * 1.minutes}">5 minutes<\/option>/, @options
    end
  end

  context 'submit_colspan' do
    setup do
      @device = FactoryGirl.build(:device)
    end

    context 'device with digital sensors' do
      setup do
        @device.stubs(:max_digital_sensors).returns(2)
      end

      should 'return #sensors plus 1' do
        assert_equal 3, submit_colspan(@device)
      end
    end

    context 'device without digital sensors' do
      should 'return 2' do
        assert_equal 2, submit_colspan(@device)
      end
    end
  end

  context 'devices_for_account' do
    setup do
      @account = FactoryGirl.create(:account)
      @device1 = FactoryGirl.create(:device, account: @account)
      @device2 = FactoryGirl.create(:device, account: @account)
      FactoryGirl.create(:device, account: nil)
    end

    context 'when no device is selected' do
      setup do
        @device_select = devices_for_account(@account)
      end

      should 'include device 1' do
        assert_match /<option value="#{@device1.id}">#{@device1.name}<\/option>/, @device_select
      end

      should 'include device 2' do
        assert_match /<option value="#{@device2.id}">#{@device2.name}<\/option>/, @device_select
      end

      should 'only include two devices' do
        assert_equal 2, @device_select.scan(/<option value=".+">.+<\/option>/).length
      end

      should 'contain a blank option' do
        assert_match /<option value=""><\/option>/, @device_select
      end

      should 'submit on change' do
        assert /onchange=this.form.submit();/, @device_select
      end
    end

    context 'when device is selected' do
      setup do
        @device_select = devices_for_account(@account, @device1.id)
      end

      should 'set @device1 as selected' do
        assert_match /<option selected="selected" value="#{@device1.id}">#{@device1.name}<\/option>/, @device_select
      end
    end
  end
end
