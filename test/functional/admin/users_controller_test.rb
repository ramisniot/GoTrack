require 'test_helper'

class Admin::UsersControllerTest < ActionController::TestCase
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
    get :index, {}
    assert_response :success
  end

  def test_users_table
    sign_in users(:dennis)
    get :index, {}
    assert_select "table tr", 8
  end

  def test_new_user
    sign_in users(:dennis)
    get :new, {}
    assert_response :success
  end

  context 'POST create' do
    setup do
      @user = FactoryGirl.create(:test_superadmin)
      sign_in @user

      @attrs = {
        first_name: "dennis",
        last_name: "baldwin",
        password: "helloworld",
        password_confirmation: "helloworld",
        account_id: FactoryGirl.create(:account).id,
        email: "dennisb@gotrackinc.com"
      }
    end

    context 'with invalid attributes' do
      setup do
        @attrs.delete(:email)
        post :create, { user: @attrs }
      end

      should 'render new template with flash error message' do
        assert_template :new
        assert_match(/Email can't be blank/, flash[:error])
      end
    end

    context 'with valid attributes' do
      setup do
        post :create, { user: @attrs }
      end

      should 'redirect to users list with flash success message' do
        assert_redirected_to admin_users_path
        assert_equal 'dennisb@gotrackinc.com was created successfully', flash[:success]
      end
    end
  end

  def test_edit_account
    sign_in users(:dennis)
    get :edit, { id: 1 }
    assert_response :success
  end

  context 'POST update' do
    setup do
      sign_in FactoryGirl.create(:test_superadmin)
      @user = FactoryGirl.create(:user)

      @attrs = {
        first_name: 'dennis_new',
        last_name: 'baldwin_new',
        email: @user.email,
        account_id: @user.account_id
      }
    end

    context 'with invalid attributes' do
      setup do
        @attrs[:first_name] = ''
        post :update, { id: @user.id, user: @attrs }
      end

      should 'render edit template with flash error message' do
        assert_template :edit
        assert_match(/First name can't be blank/, flash[:error])
      end
    end

    context 'with valid attributes' do
      setup do
        post :update, { id: @user.id, user: @attrs }
      end

      should 'redirect to users list with flash success message' do
        assert_redirected_to admin_users_path
        assert_equal("#{@user.email} updated successfully", flash[:success])
      end
    end
  end

  context 'search' do
    setup do
      @user = FactoryGirl.create(:user, first_name: 'first_name')
      @device = FactoryGirl.create(:device, account: @user.account)
      sign_in users(:dennis)
    end

    context 'search without account' do
      should 'return no users when the keyword does not match any name' do
        post :index, { search: { first_name_or_last_name_or_email_cont: 'non_exists_name_like_this' } }
        assert_response :success
        assert_equal [], assigns(:users)
      end

      should 'return the user whose name matches the keyword' do
        post :index, { search: { first_name_or_last_name_or_email_cont: 'first_name' } }
        assert_response :success
        assert_equal [@user], assigns(:users)
      end
    end

    context 'search with account' do
      setup do
        @account = FactoryGirl.create(:account)
        FactoryGirl.create(:user, email: 'some@some.com', first_name: 'first_name', account: @account)
      end

      should 'return only the user that belongs to the account passed' do
        post :index, { search: { account_id_eq: @account.id } }
        assert_response :success
        assert_equal @account.users, assigns(:users)
      end
    end
  end
end
