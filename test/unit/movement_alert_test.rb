require 'test_helper'

class MovementAlertTest < ActiveSupport::TestCase
  fixtures :devices, :users, :readings

  setup do
    MovementAlert.delete_all
  end

  test "duplicate movement alerts are forbidden" do
    m1 = MovementAlert.create(user_id: 1, device_id: 1, violating_reading_id: nil)
    assert m1.errors.empty?

    m2 = MovementAlert.create(user_id: 1, device_id: 1, violating_reading_id: nil)
    assert m2.errors.any?
  end

  test "measures violation correctly" do
    m1 = MovementAlert.create(user_id: 1, device_id: 1, latitude: 30.40473, longitude: -97.69441)
    r1 = Reading.create(device_id: 1, latitude: 30.40565, longitude: -97.69399, recorded_at: DateTime.now)
    r2 = Reading.create(device_id: 1, latitude: 30.40702, longitude: -97.69233, recorded_at: DateTime.now)

    assert_not m1.is_violated_by(r1)
    assert m1.is_violated_by(r2)
  end
end
