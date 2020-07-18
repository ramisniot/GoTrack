require 'test_helper'

class UtilsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  fixtures :users, :accounts, :readings, :devices

  should use_before_filter(:authorize)

  def test_set_movement_alert
    d = FactoryGirl.create(:device)
    u = FactoryGirl.create(:user)

    mc = MovementAlert.count

    sign_in users(:dennis)
    get :set_movement_alert, { id: d.id, lat: 30.40473, lng: -97.69441 }
    assert_response :success
    assert_equal "EZ-Alert has been set", @response.body
    assert assigns(:movement_alert).errors.empty?
  end

  test 'view preference' do
    user = users(:dennis)
    sign_in user

    get :set_view_preference, type: 'geofences'
    assert_response :success
    assert_not User.find(user.id).view_overlays?(:geofences)

    get :set_view_preference, type: 'placemarks'
    assert_response :success
    assert_not User.find(user.id).view_overlays?(:placemarks)

    get :set_view_preference, type: 'geofences', checked: 'y'
    assert_response :success
    assert User.find(user.id).view_overlays?(:geofences)

    get :set_view_preference, type: 'placemarks', checked: 'y'
    assert_response :success
    assert User.find(user.id).view_overlays?(:placemarks)

    get :set_view_preference, map: ''
    assert_response :success
    assert_equal '', User.find(user.id).default_map_type

    get :set_view_preference, map: 'hybrid'
    assert_response :success
    assert_equal 'hybrid', User.find(user.id).default_map_type

    get :set_view_preference, map: 'roadmap'
    assert_response :success
    assert_equal 'roadmap', User.find(user.id).default_map_type
  end
end
