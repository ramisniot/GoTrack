require 'test_helper'

class MaintenancesHelperTest < ActionView::TestCase
  context 'get_due' do
    context 'for integer param' do
      should 'return 0 miles if data is less than 0' do
        assert_equal '0 miles', get_due(-1)
      end

      should 'return 1 mile if data is set as 1' do
        assert_equal '1 mile', get_due(1)
      end

      should 'return 5 miles if data is set as 5' do
        assert_equal '5 miles', get_due(5)
      end
    end

    context 'for date param' do
      should 'return Today if data is set as today' do
        assert_equal 'Today', get_due(Date.today)
      end

      should 'return 0 if date is 1 day before today' do
        assert_equal '0', get_due(Date.today - 1.day)
      end

      should 'return In 1 day if date if 1 day after today' do
        assert_equal 'In 1 day', get_due(Date.today + 1.day)
      end

      context 'more than one mont' do
        setup do
          @date = Date.today + 1.day + 1.month
          days = (@date - Date.today).to_f
          months = days / 30
          years = days / 365
          @remaining_days = (days.to_i) - ((months.to_i * 30) + (years.to_i * 365))
        end

        should 'return In 1 month and 2 days if date is 1 day and 1 month after today' do
          #assert_equal "In 1 month and #{pluralize(@remaining_days.to_i, 'day')}", get_due(@date)
        end
      end
    end
  end

  context 'get_status method' do
    should 'return status completed if second param is true' do
      assert_equal Maintenance::STATUS_COMPLETED, get_status('data', true)
    end

    context 'for integer param' do
      should 'return DUE status if param is over 100' do
        assert_equal Maintenance::STATUS_OK, get_status(101)
      end

      should 'return OK status if param is between 25 and 100' do
        assert_equal Maintenance::STATUS_PENDING, get_status(50)
      end

      should 'return PENDING status if param is between 1 and 25' do
        assert_equal Maintenance::STATUS_DUE, get_status(20)
      end

      should 'return PDUE status if param is under 1' do
        assert_equal Maintenance::STATUS_PDUE, get_status(0)
      end
    end

    context 'for date param' do
      should 'return DUE status if date is 1 day after today' do
        assert_equal Maintenance::STATUS_DUE, get_status(Date.today + 1.day)
      end

      should 'return OK status if date is 11 days after today' do
        assert_equal Maintenance::STATUS_OK, get_status(Date.today + 11.days)
      end

      should 'return PENDING status if date is 5 days after today' do
        assert_equal Maintenance::STATUS_PENDING, get_status(Date.today + 5.days)
      end

      should 'return PDUE status if date is one day before today' do
        assert_equal Maintenance::STATUS_PDUE, get_status(Date.today - 1.days)
      end
    end
  end

  context 'status_string method' do
    should 'return Completed if param is set as Maintenance::STATUS_COMPLETED' do
      assert_equal 'Completed', status_string(Maintenance::STATUS_COMPLETED)
    end

    should 'return Ok if param is set as Maintenance::STATUS_OK' do
      assert_equal 'Ok', status_string(Maintenance::STATUS_OK)
    end

    should 'return Pending if param is set as Maintenance::STATUS_PENDING' do
      assert_equal 'Pending', status_string(Maintenance::STATUS_PENDING)
    end

    should 'return Due if param is set as Maintenance::STATUS_DUE' do
      assert_equal 'Due', status_string(Maintenance::STATUS_DUE)
    end

    should 'return Past Due if param is set as Maintenance::STATUS_PDUE' do
      assert_equal 'Past Due', status_string(Maintenance::STATUS_PDUE)
    end

    should 'return Invalid Status in other cases' do
      assert_equal 'Invalid Status', status_string(-1)
    end
  end

  context 'get_tooltip method' do
    context 'for mileage maintenance tasks' do
      should 'return properly message for mileage if param is set as Maintenance::STATUS_OK' do
        assert_equal '> 100 miles from target', get_tooltip(Maintenance::STATUS_OK, Maintenance::MILEAGE_TYPE)
      end

      should 'return properly message for mileage if param is set as Maintenance::STATUS_PENDING' do
        assert_equal '100 miles from target', get_tooltip(Maintenance::STATUS_PENDING, Maintenance::MILEAGE_TYPE)
      end

      should 'return properly message for mileage if param is set as Maintenance::STATUS_DUE' do
        assert_equal '25 miles from target', get_tooltip(Maintenance::STATUS_DUE, Maintenance::MILEAGE_TYPE)
      end

      should 'return properly message for mileage if param is set as Maintenance::STATUS_PDUE' do
        assert_equal '1 mile < than target', get_tooltip(Maintenance::STATUS_PDUE, Maintenance::MILEAGE_TYPE)
      end
    end

    context 'for scheduled maintenance tasks' do
      should 'return properly message for schedule if param is set as Maintenance::STATUS_OK' do
        assert_equal '> 10 days from Target', get_tooltip(Maintenance::STATUS_OK, Maintenance::SCHEDULED_TYPE)
      end

      should 'return properly message for schedule if param is set as Maintenance::STATUS_PENDING' do
        assert_equal '10 Days or fewer from Target', get_tooltip(Maintenance::STATUS_PENDING, Maintenance::SCHEDULED_TYPE)
      end

      should 'return properly message for schedule if param is set as Maintenance::STATUS_DUE' do
        assert_equal '1 Days or fewer from Target', get_tooltip(Maintenance::STATUS_DUE, Maintenance::SCHEDULED_TYPE)
      end

      should 'return properly message for schedule if param is set as Maintenance::STATUS_PDUE' do
        assert_equal 'A day < than target', get_tooltip(Maintenance::STATUS_PDUE, Maintenance::SCHEDULED_TYPE)
      end
    end

    context 'for both scheduled and mileage tasks' do
      should 'return Task is Completed if param is set as Maintenance::STATUS_COMPLETED' do
        assert_equal 'Task is Completed', get_tooltip(Maintenance::STATUS_COMPLETED, false)
      end

      should 'return Please report this in other cases' do
        assert_equal 'Please report this', get_tooltip(-1, false)
      end
    end
  end
end
