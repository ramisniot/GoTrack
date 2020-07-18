require 'test_helper'

class GroupsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  fixtures :users, :devices, :accounts, :groups, :device_profiles

  module RequestExtensions
    def server_name
      "helo"
    end

    def path_info
      "adsf"
    end
  end

  def setup
    @request.extend(RequestExtensions)
  end

  def test_index
    sign_in users(:dennis)
    get :index, {}
    assert_response :success
  end

  def test_new
    sign_in users(:dennis)
    post :create, { id: "7", name: "summer of code", select_devices: [4], sel: "4", account_id: "1" }
    assert_equal "Fleet summer of code was successfully added", flash[:success]
    group = Group.find_by_name("summer of code")
    assert_equal group.name, "summer of code"
    assert_redirected_to groups_path
  end

  def test_new_invalid_group
    sign_in users(:dennis)
    post :create, { id: "7", name: "", select_devices: nil, sel: "4", account_id: "1" }
    assert_equal "Fleet name can't be blank <br/>You must select at least one device ", flash[:error]
    assert_redirected_to new_group_path
  end

  def test_edit
    sign_in users(:dennis)
    put :update, { id: "1", name: "summer of code", select_devices: [4], sel: "4", account_id: "1" }
    assert_equal "Fleet summer of code was updated successfully ", flash[:success]
    group = Group.find_by_name("summer of code")
    assert_equal group.name, "summer of code"
    assert_redirected_to groups_path
  end

  def test_edits_for_group_id
    sign_in users(:dennis)
    get :edit, { id: "1" }
    assert_equal 'Dennis', flash[:group_name]
  end

  def test_edit_invalid_group
    sign_in users(:dennis)
    put :update, { id: "1", name: "", select_devices: nil, sel: "4", account_id: "1" }
    assert_equal "Fleet name can't be blank <br/>You must select at least one device ", flash[:error]
    assert_redirected_to edit_group_path
  end

  def test_delete
    sign_in users(:nick)
    post :destroy, { id: "6" }
    assert_equal "Fleet Dragon was deleted successfully ", flash[:success]
    assert_redirected_to groups_path
  end

  def test_index_notauthorized
    get :index
    assert_redirected_to new_user_session_path
  end
end
