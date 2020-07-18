require 'test_helper'

class MaintenanceTest < ActiveSupport::TestCase
  should validate_presence_of(:device_id)
  should validate_presence_of(:type_task)
  should validate_presence_of(:description_task)
  should validate_length_of(:description_task).is_at_most(Maintenance::MAX_LENGTH[:description_task])
  should validate_numericality_of(:mileage)

  setup do
    # @todo Remove this once we get rid of all the fixtures
    Maintenance.delete_all
  end

  context '#completed' do
    setup do
      @completed_maintenance_one = FactoryGirl.create(:maintenance, completed_at: Time.now)
      @completed_maintenance_two = FactoryGirl.create(:maintenance, completed_at: Time.now)
      @uncompleted_maintenance = FactoryGirl.create(:maintenance)
    end

    should 'return the maintenance tasks marked as completed' do
      completed_maintenances = Maintenance.completed

      assert_same_elements([@completed_maintenance_one, @completed_maintenance_two], completed_maintenances)
    end
  end

  context '#not_completed' do
    setup do
      @completed_maintenance_one = FactoryGirl.create(:maintenance, completed_at: Time.now)
      @completed_maintenance_two = FactoryGirl.create(:maintenance, completed_at: Time.now)
      @uncompleted_maintenance_one = FactoryGirl.create(:maintenance)
      @uncompleted_maintenance_two = FactoryGirl.create(:maintenance)
    end

    should 'return the uncompleted maintenance tasks' do
      uncompleted_maintenances = Maintenance.not_completed

      assert_same_elements([@uncompleted_maintenance_one, @uncompleted_maintenance_two], uncompleted_maintenances)
    end
  end

  context '#mileage' do
    setup do
      @scheduled_maintenance_one = FactoryGirl.create(:schedule_maintenance)
      @scheduled_maintenance_two = FactoryGirl.create(:schedule_maintenance)
      @mileage_maintenance_one = FactoryGirl.create(:mileage_maintenance)
      @mileage_maintenance_two = FactoryGirl.create(:mileage_maintenance)
    end

    should 'return the maintenance tasks of type mileage' do
      mileage_maintenances = Maintenance.mileage

      assert_same_elements([@mileage_maintenance_one, @mileage_maintenance_two], mileage_maintenances)
    end
  end

  context '#with_an_active_device' do
    setup do
      active_device = FactoryGirl.create(:device)
      inactive_device = FactoryGirl.create(:inactive_device)

      @maintenance_one = FactoryGirl.create(:maintenance, device: active_device)
      @maintenance_two = FactoryGirl.create(:maintenance, device: active_device)
      FactoryGirl.create(:maintenance, device: inactive_device)
    end

    should 'return the maintenance tasks belonging to an active device' do
      maintenances_with_an_active_device = Maintenance.with_an_active_device

      assert_equal([@maintenance_one, @maintenance_two], maintenances_with_an_active_device)
    end
  end

  context '#is_scheduled?' do
    should 'return true if the maintenance task is scheduled' do
      scheduled_maintenance = FactoryGirl.build(:schedule_maintenance)

      assert scheduled_maintenance.is_scheduled?
    end

    should 'return false if the maintenance task is mileage' do
      mileage_maintenance = FactoryGirl.build(:mileage_maintenance)

      refute mileage_maintenance.is_scheduled?
    end
  end

  context '#is_mileage?' do
    should 'return true if the maintenance task is mileage' do
      mileage_maintenance = FactoryGirl.build(:mileage_maintenance)

      assert mileage_maintenance.is_mileage?
    end

    should 'return false if the maintenance task is scheduled' do
      scheduled_maintenance = FactoryGirl.build(:schedule_maintenance)

      refute scheduled_maintenance.is_mileage?
    end
  end

  context '#type' do
    should 'return the type of the maintenance task' do
      scheduled_maintenance = FactoryGirl.build(:schedule_maintenance)
      mileage_maintenance = FactoryGirl.build(:mileage_maintenance)

      assert_equal(Maintenance::SCHEDULED_TYPE, scheduled_maintenance.type)
      assert_equal(Maintenance::MILEAGE_TYPE, mileage_maintenance.type)
    end
  end

  context '#type_string' do
    should 'return the type of the maintenance task as a string' do
      scheduled_maintenance = FactoryGirl.build(:schedule_maintenance)
      mileage_maintenance = FactoryGirl.build(:mileage_maintenance)

      assert_equal('Scheduled', scheduled_maintenance.type_string)
      assert_equal('Mileage', mileage_maintenance.type_string)
    end
  end

  context '#target_string' do
    context 'when type is scheduled' do
      should 'return the scheduled time as a string' do
        scheduled_maintenance = FactoryGirl.build(:schedule_maintenance, scheduled_time: Time.new(2017, 11, 14))

        assert_equal('14-Nov-2017', scheduled_maintenance.target_string)
      end
    end

    context 'when type is mileage' do
      should 'return the targeted miles' do
        mileage_maintenance = FactoryGirl.build(:mileage_maintenance)

        assert_equal('20 miles', mileage_maintenance.target_string)
      end
    end
  end

  context '#actual_string' do
    context 'when type is scheduled' do
      should 'return the scheduled time as a string' do
        scheduled_maintenance = FactoryGirl.build(:schedule_maintenance)
        scheduled_maintenance.stubs(standard_date: '14-Nov-2017')

        assert_equal('14-Nov-2017', scheduled_maintenance.actual_string)
      end
    end

    context 'when type is mileage' do
      should 'return the targeted miles' do
        mileage_maintenance = FactoryGirl.build(:mileage_maintenance)
        mileage_maintenance.stubs(device_mileage: 20)

        assert_equal('20 miles', mileage_maintenance.actual_string)
      end
    end
  end

  context '#is_completed?' do
    should 'return true if maintenance is completed' do
      completed_maintenance = FactoryGirl.build(:maintenance, completed_at: Time.now)

      assert completed_maintenance.is_completed?
    end

    should 'return false if maintenance is uncompleted' do
      uncompleted_maintenance = FactoryGirl.build(:maintenance)

      refute uncompleted_maintenance.is_completed?
    end
  end

  context '#status' do
    context 'when the maintenance is completed' do
      should 'return STATUS_COMPLETED' do
        maintenance = FactoryGirl.build(:maintenance, completed_at: Time.now)

        assert_equal Maintenance::STATUS_COMPLETED, maintenance.status
      end
    end

    context 'when the maintenance is mileage' do
      setup do
        @maintenance = FactoryGirl.build(:mileage_maintenance)
      end

      should 'return STATUS_OK if remaining miles are above 100' do
        @maintenance.stubs(remaining_miles: 101)

        assert_equal Maintenance::STATUS_OK, @maintenance.status
      end

      should 'return STATUS_PENDING if remaining miles are between 25 and 100' do
        @maintenance.stubs(remaining_miles: 100)

        assert_equal Maintenance::STATUS_PENDING, @maintenance.status
      end

      should 'return STATUS_DUE if remaining miles are between 1 and 25' do
        @maintenance.stubs(remaining_miles: 25)

        assert_equal Maintenance::STATUS_DUE, @maintenance.status
      end

      should 'return STATUS_PDUE if remaining miles are less than 1' do
        @maintenance.stubs(remaining_miles: 0)

        assert_equal Maintenance::STATUS_PDUE, @maintenance.status
      end
    end

    context 'when the maintenance is scheduled' do
      setup do
        @maintenance = FactoryGirl.build(:schedule_maintenance, scheduled_time: Time.now)
      end

      should 'return STATUS_OK if difference between today and scheduled time is 10 days or more' do
        Date.stubs(today: (Time.now - 15.days).to_date)

        assert_equal Maintenance::STATUS_OK, @maintenance.status
      end

      should 'return STATUS_PENDING if difference between today and scheduled time is between 1 and 10 days' do
        Date.stubs(today: (Time.now - 9.days).to_date)

        assert_equal Maintenance::STATUS_PENDING, @maintenance.status
      end

      should 'return STATUS_DUE if difference between today and scheduled time is between 0 and 1 day' do
        Date.stubs(today: (Time.now - 1.day).to_date)

        assert_equal Maintenance::STATUS_DUE, @maintenance.status
      end

      should 'return STATUS_PDUE if scheduled time is a day late or more' do
        Date.stubs(today: (Time.now + 2.days).to_date)

        assert_equal Maintenance::STATUS_PDUE, @maintenance.status
      end
    end
  end

  context '#alert_status' do
    context 'when maintenance is mileage' do
      setup do
        @maintenance = FactoryGirl.build(:mileage_maintenance)
        @maintenance.stubs(remaining_miles: 20)
      end

      should 'return nil if status is STATUS_OK' do
        @maintenance.stubs(status: Maintenance::STATUS_OK)

        assert_nil @maintenance.alert_status
      end

      should 'return STATUS_PENDING reminder if status is STATUS_PENDING' do
        @maintenance.stubs(status: Maintenance::STATUS_PENDING)

        assert_equal "Reminder: Maintenance task 'Maintenance Test' will be due in 20.0 miles", @maintenance.alert_status
      end

      should 'return STATUS_DUE reminder if status is STATUS_DUE' do
        @maintenance.stubs(status: Maintenance::STATUS_DUE)

        assert_equal "Due: Maintenance task 'Maintenance Test' will be due in 20.0 miles", @maintenance.alert_status
      end

      should 'return STATUS_PDUE reminder if status is STATUS_PDUE' do
        @maintenance.stubs(status: Maintenance::STATUS_PDUE)

        assert_equal "Past Due: Maintenance task 'Maintenance Test' was due 20.0 miles ago", @maintenance.alert_status
      end
    end

    context 'when maintenance is scheduled' do
      setup do
        @maintenance = FactoryGirl.build(:schedule_maintenance, scheduled_time: Time.new(2017, 11, 14))
      end

      should 'return nil if status is STATUS_OK' do
        @maintenance.stubs(status: Maintenance::STATUS_OK)

        assert_nil @maintenance.alert_status
      end

      should 'return STATUS_PENDING reminder if status is STATUS_PENDING' do
        @maintenance.stubs(status: Maintenance::STATUS_PENDING)

        assert_equal "Reminder: Maintenance task 'Maintenance Test' will be due on 2017-11-14", @maintenance.alert_status
      end

      should 'return STATUS_DUE reminder if status is STATUS_DUE' do
        @maintenance.stubs(status: Maintenance::STATUS_DUE)

        assert_equal "Due: Maintenance task 'Maintenance Test' will be due Today", @maintenance.alert_status
      end

      should 'return STATUS_PDUE reminder if status is STATUS_PDUE' do
        @maintenance.stubs(status: Maintenance::STATUS_PDUE)

        assert_equal "Past Due: Maintenance task 'Maintenance Test' was due on 2017-11-14", @maintenance.alert_status
      end
    end
  end

  context '#remaining_miles' do
    context 'when maintenance is scheduled' do
      setup do
        @maintenance = FactoryGirl.build(:schedule_maintenance)
      end

      should 'return nil' do
        assert_nil @maintenance.remaining_miles
      end
    end

    context 'when maintenance is mileage' do
      setup do
        @maintenance = FactoryGirl.build(:mileage_maintenance)
      end

      should 'return the remaining miles' do
        assert_equal 20, @maintenance.remaining_miles
      end
    end
  end
end
