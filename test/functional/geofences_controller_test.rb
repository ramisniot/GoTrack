require 'test_helper'

class GeofencesControllerTest < ActionController::TestCase
  # TODO remove fixtures and address 'button_to_function' issue
  # include Devise::Test::ControllerHelpers
  # fixtures :devices, :users, :accounts, :geofences
  #
  # def setup
  #   request.env['HTTP_REFERER'] = '/geofences'
  #
  #   def @request.server_name
  #     {}
  #   end
  #
  #   def @request.path_info
  #     ''
  #   end
  #
  #   sign_in users(:dennis)
  # end
  #
  # def test_index
  #   get :index, {}
  #   assert_not_nil assigns(:geofences)
  # end
  #
  # def test_index_with_empty_params
  #   sign_in users(:ken)
  #
  #   get :index, {}
  #   assert_response :success
  # end
  #
  # context 'new' do
  #   context 'admin user' do
  #     setup do
  #       sign_in users(:dennis)
  #       get :new
  #     end
  #
  #     should 'response successfully without flash message' do
  #       assert_response :success
  #       assert_nil flash.now[:error]
  #     end
  #   end
  #
  #   context 'non admin user' do
  #     setup do
  #       sign_in users(:demo)
  #       get :new
  #     end
  #
  #     should 'response successfully with flash message' do
  #       assert_response :success
  #       assert_equal 'Only Admin users can create Locations', flash.now[:error]
  #     end
  #   end
  # end
  #
  # context 'create' do
  #   context 'with admin user' do
  #     should 'render new with error message if not valid data' do
  #       post :create, { radio: 2, geofence: { device_id: 1234, polygonal: '0', latitude: '1', longitude: '2', name: '', address: '1600 Penn Ave' } }
  #       assert_template 'new'
  #       assert_equal 'Location not created', flash[:error]
  #     end
  #
  #     should 'redirect to geofences list with success message if valid data' do
  #       post :create, { radio: 1, geofence: { polygonal: '0', radius: 1, latitude: '1', longitude: '2', name: 'qwerty', address: '1600 Penn Ave' } }
  #       assert_redirected_to controller: 'geofences', action: 'index'
  #       assert_equal 'qwerty created successfully.', @request.flash[:success]
  #     end
  #   end
  #
  #   context 'with non admin user' do
  #     setup do
  #       sign_in users(:demo)
  #       post :create, { radio: 1, geofence: { polygonal: '0', radius: 1, latitude: '1', longitude: '2', name: 'qwerty', address: '1600 Penn Ave' } }
  #     end
  #
  #     should 'render new with error message' do
  #       assert_template 'new'
  #       assert_equal 'Only Admin users can create Locations', flash.now[:error]
  #     end
  #   end
  # end
  #
  # def test_delete
  #   delete :destroy, id: '1'
  #   assert_redirected_to controller: 'geofences', action: 'index'
  #   assert_equal 'home deleted successfully.', flash[:success]
  # end
  #
  # def test_delete_geofence_by_invalid_user
  #   sign_in users(:ken)
  #   delete :destroy, id: '1'
  #   assert_equal 'Invalid action.', flash[:error]
  #   assert_redirected_to controller: 'geofences', action: 'index'
  # end
  #
  # def test_delete_unknown_geofence
  #   delete :destroy, id: '17521'
  #   assert_equal 'Invalid action.', flash[:error]
  #   assert_redirected_to controller: 'geofences', action: 'index'
  # end
  #
  # def test_update
  #   put :update, { id: '1', geofence: { latitude: '1', longitude: '2', polygonal: '0', name: 'qwerty', address: '1600 Penn Ave', notify_enter_exit: 0 }, radio: '2' }
  #
  #   assert_equal false, Geofence.find(1).notify_enter_exit
  #   assert_equal 'qwerty updated successfully.', flash[:success]
  #   assert_redirected_to controller: 'geofences', action: 'index'
  # end
  #
  # def test_edit_invalid_geofence
  #   get :edit, id: '12311'
  #   assert_equal 'Invalid action.', flash[:error]
  # end
  #
  # def test_edit_unauthorized_geofence
  #   sign_in users(:ken)
  #   post :edit, id: '1'
  #   assert_equal 'Invalid action.', flash[:error]
  # end
  #
  # def test_delete_unauthorized
  #   sign_in users(:ken)
  #   delete :destroy, id: '2'
  #   assert_equal 'Invalid action.', flash[:error]
  # end
  #
  # context 'for_device' do
  #   setup do
  #     @user = users(:ken)
  #     sign_in @user
  #   end
  #
  #   context 'device belongs to current user account' do
  #     setup do
  #       @device = FactoryGirl.create(:device, name: 'device', account: @user.account)
  #       @geofence = FactoryGirl.create(:geofence, device: @device, name: 'Geofence1')
  #       get :for_device, { device_id: @device.id }
  #     end
  #
  #     should 'be success' do
  #       assert_response :success
  #       assert @response.body.to_s.include?('All Locations for device (1 total)')
  #     end
  #
  #     should 'geofences variable have @geofence element' do
  #       assert_equal [@geofence], assigns(:geofences)
  #     end
  #
  #     should 'assign @geofences_count to 1' do
  #       assert_equal 1, assigns(:geofence_count)
  #     end
  #
  #     should 'assign device variable to @device' do
  #       assert_equal @device, assigns(:device)
  #     end
  #   end
  #
  #   context 'device doesn\'t belong to current user account' do
  #     setup do
  #       account = FactoryGirl.create(:account)
  #       @device = FactoryGirl.create(:device, name: 'device', account: account)
  #       @geofence = FactoryGirl.create(:geofence, device: @device, name: 'Geofence1')
  #       get :for_device, { device_id: @device.id }
  #     end
  #
  #     should 'redirect to home page' do
  #       assert_redirected_to home_path
  #     end
  #
  #     should 'set the correct flash message' do
  #       assert_equal 'You are not allowed to see the selected device', flash[:error]
  #     end
  #   end
  # end
end
