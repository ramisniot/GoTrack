require 'test_helper'

class Admin::AccountsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  fixtures :users, :accounts

  module RequestExtensions
    def server_name
      'helo'
    end

    def path_info
      'adsf'
    end
  end

  setup do
    @request.extend(RequestExtensions)
    sign_in users(:dennis)
  end

  context 'index' do
    should 'respond properly' do
      get :index, {}
      assert_response :success
    end

    should 'exist a table with 8 rows' do
      get :index, {}
      assert_select 'table tr', 8
    end
  end

  context 'new' do
    should 'respond properly' do
      get :new, {}
      assert_response :success
    end
  end

  context 'create' do
    context 'when successfully post to QIOT' do
      setup do
        @collection_token = 'token'
        QiotApi.stubs(:create_collection).returns(success: true, data: { 'collection': { 'collection_token': @collection_token } })
        post :create, account: { subdomain: 'monkey', address: '123 Foo St', company: 'New Co', zip: 12_345 }
      end

      context 'and account params are valid' do
        should 'redirect to index' do
          assert_redirected_to action: :index
        end

        should 'show flash success message' do
          assert_equal flash[:success], 'New Co created successfully'
        end

        should 'create account with collection_token' do
          assert Account.find_by(collection_token: @collection_token)
        end
      end

      context 'and account params are invalid' do
        setup do
          post :create, account: { subdomain: 'monkey', address: '123 Foo St', company: nil }
        end

        should 'not create account' do
          assert Account.find_by(company: 'New Co')
        end
      end
    end

    context 'when post to QIOT fails' do
      setup do
        @error = 'QIOT post error'
        QiotApi.stubs(:create_collection).returns(success: false, error: @error)
        post :create, account: { subdomain: 'monkey', address: '123 Foo St', company: 'New Co', zip: 12_345 }
      end

      should 'render new template' do
        assert_template :new
      end

      should 'show flash error message' do
        assert_equal flash[:error], @error
      end
    end
  end

  context 'edit' do
    should 'respond properly' do
      get :edit, id: 4
      assert_response :success
    end
  end

  context 'update' do
    context 'when successfully post to QIOT' do
      setup do
        @collection_token = 'token'
        QiotApi.stubs(:update_collection).returns(success: true)
      end

      context 'state mileage visibility' do
        context 'enabled' do
          setup do
            Account.find(4).update_attribute(:show_state_mileage_report, false)
          end

          should 'change attribute show_state_mileage_report to true' do
            post :update, id: 4, account: { subdomain: 'newco', address: '123 Foo St', company: 'New Co', zip: 12_345 }, options: { show_state_mileage_report: 'on' }

            assert Account.find(4).show_state_mileage_report?
          end
        end

        context 'disabled' do
          setup do
            Account.find(4).update_attribute(:show_state_mileage_report, true)
          end

          should 'change attribute show_state_mileage_report to false' do
            post :update, id: 4, account: { subdomain: 'newco', address: '123 Foo St', company: 'New Co', zip: 12_345 }, options: { show_state_mileage_report: 'off' }

            assert_not Account.find(4).show_state_mileage_report?
          end
        end
      end
    end

    context 'when post to QIOT fails' do
      setup do
        @error = 'QIOT post error'
        QiotApi.stubs(:update_collection).returns(success: false, error: @error)
        post :update, id: 4, account: { subdomain: 'newco', address: '123 Foo St', company: 'New Co', zip: 12_345 }
      end

      should 'render edit' do
        assert_template :edit
      end

      should 'show flash error message' do
        assert_equal flash[:error], @error
      end
    end
  end

  context 'delete' do
    context 'when successfully post to QIOT' do
      setup do
        @collection_token = 'token'
        QiotApi.stubs(:delete_collection).returns(success: true)
      end

      should 'redirect to index with flash success message' do
        post :destroy, id: 1
        assert_redirected_to action: 'index'
        assert_equal flash[:success], 'dennis deleted successfully'
      end
    end

    context 'when post to QIOT fails' do
      setup do
        @error = 'QIOT post error'
        QiotApi.stubs(:delete_collection).returns(success: false, error: @error)
        post :destroy, id: 1
      end

      should 'redirect to action index' do
        assert_redirected_to action: :index
      end

      should 'show flash error message' do
        assert_equal flash[:error], @error
      end
    end
  end
end
