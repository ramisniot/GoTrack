require 'test_helper'

class UsersControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  fixtures :users, :accounts

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
    get :index, { id: 1 }
    assert_response :success
  end

  def test_edit_user
    sign_in users(:dennis)
    params = { first_name: "qwerty", last_name: "asdf", email: "asdf@bar.com" }
    put :update, { id: 1, user: params }

    assert_redirected_to controller: "users"
    assert_equal "qwerty", User.find(1).first_name
  end

  def test_edit_user_unauthorized
    sign_in users(:dennis)
    params = { first_name: "qwerty", last_name: "asdf", email: "asdf" }
    put :update, { id: 2, user: params }
    assert_redirected_to "/user/sign_out"
    assert_not_equal "qwerty", User.find(2).first_name
  end

  def test_get_user
    sign_in users(:dennis)
    get :edit, { id: 1 }
    assert_response :success
    user = assigns(:user)
    assert_equal "dennis", user.first_name
  end

  def test_get_user_unauthorized
    sign_in users(:dennis)
    get :edit, { id: 2 }
    assert_redirected_to "/user/sign_out"
    assert_nil assigns(:user)
  end

  def test_short_password
    sign_in users(:dennis)
    params = { first_name: "qwerty", last_name: "asdf", email: "asdf" }
    post :update, { id: 1, user: params, new_password: "test" }
    assert_response :success
    assert_equal flash[:error], "Your existing password must match what's currently stored in our system"
  end

  context 'new' do
    should 'redirect to home if user is not logged in' do
      get :new, {}
      assert_redirected_to '/user/sign_in'
    end

    should 'render new if user is logged in' do
      sign_in users(:dennis)
      get :new, {}
      assert_response :success
      assert_template :new
    end
  end

  context 'create'do
    setup do
      sign_in users(:dennis)
    end

    should 'create a user and redirect to users index page' do
      params = { first_name: "dennis", last_name: "baldwin", email: "dennisbaldwin@gmail.com", password: "testing123", password_confirmation: "testing123" }
      post :create, { user: params }
      assert_redirected_to controller: "users"
    end

    should 'not create a user if the email already exists' do
      params = { first_name: "dennis", last_name: "baldwin", email: "dennis@gotrackinc.com", password: "testing123", password_confirmation: "testing123" }
      post :create, { user: params }
      assert_response :success
      assert_match /Email has already been taken/, flash[:error]
      assert_template 'new'
    end

    should 'not create a user if first name is missing' do
      params = { first_name: "", last_name: "baldwin", email: "admin@moove-it.com", password: "testing123", password_confirmation: "testing123" }
      post :create, { user: params }
      assert_response :success
      assert_match /First name can't be blank/, flash[:error]
      assert_template 'new'
    end

    should 'not create a user if password does not match' do
      params = { first_name: "Alice", last_name: "baldwin", email: "admin@moove-it.com", password: "password 1", password_confirmation: "password 2" }
      post :create, { user: params }
      assert_response :success
      assert_match /Your new password and confirmation must match/, flash[:error]
      assert_template 'new'
    end
  end

  def test_delete
    sign_in users(:dennis)
    #delete invalid record
    delete :destroy, { id: 1 }
    assert 302

    #delete valid record
    delete :destroy, { id: 5 }
    assert_redirected_to controller: "users"
  end
end
