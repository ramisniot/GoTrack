require 'test_helper'

class MaintenancesControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  context 'GET index' do
    context 'when unauthorized' do
      should 'redirect to login page' do
        get :index

        assert_redirected_to '/user/sign_in'
      end
    end

    context 'when authorized' do
      setup do
        @user = FactoryGirl.create(:user)
        @account_device = FactoryGirl.create(:device, account: @user.account)

        sign_in @user
      end

      should 'render template index' do
        get :index

        assert_template :index
      end

      should 'assign devices_list with account provisioned devices' do
        device_one = FactoryGirl.create(:device, account: @user.account)
        device_two = FactoryGirl.create(:device, account: @user.account)

        get :index

        assert_equal(3, assigns(:devices_list).length)
      end

      context 'when device_id is sent as a param' do
        should 'assign the maintenances of the given device' do
          device = FactoryGirl.create(:device, account: @user.account)

          FactoryGirl.create(:maintenance, device: @account_device)
          FactoryGirl.create(:maintenance, device: @account_device)
          FactoryGirl.create(:maintenance, device: device)

          get :index, { device: @account_device.id }

          assert_equal(2, assigns(:maintenances).length)
        end
      end

      context 'when task_desc is sent as a param' do
        should 'assign the maintenances that match the task description' do
          FactoryGirl.create(:maintenance, description_task: 'Maintenance John S', device: @account_device)
          FactoryGirl.create(:maintenance, description_task: 'Maintenance John S', device: @account_device)
          FactoryGirl.create(:maintenance, description_task: 'Maintenance Susan M', device: @account_device)

          get :index, { task_desc: 'Maintenance John' }

          assert_equal(2, assigns(:maintenances).length)
        end
      end

      context 'when from and to are sent as params' do
        setup do
          FactoryGirl.create(:maintenance, device: @account_device, scheduled_time: Time.new(2017, 11, 2))
          FactoryGirl.create(:maintenance, device: @account_device, scheduled_time: Time.new(2017, 11, 4))
          FactoryGirl.create(:maintenance, device: @account_device, scheduled_time: Time.new(2017, 11, 6))
        end

        should 'assign the maintenances scheduled between the given time' do
          get :index, { from: '2017-11-1', to: '2017-11-5' }

          assert_equal(2, assigns(:maintenances).length)
        end

        should 'not assign any maintenance if the date is invalid' do
          get :index, { from: 'invalid-date', to: 'invalid-date' }

          assert_equal(0, assigns(:maintenances).length)
        end
      end

      context 'when status is sent as a param' do
        context 'when status is COMPLETED' do
          should 'assign the completed maintenances' do
            FactoryGirl.create(:maintenance, device: @account_device, completed_at: Time.now)
            FactoryGirl.create(:maintenance, device: @account_device, completed_at: Time.now)
            FactoryGirl.create(:maintenance, device: @account_device)

            get :index, { status: Maintenance::STATUS_COMPLETED.to_s }

            assert_equal(2, assigns(:maintenances).length)
          end
        end

        context 'when status is OK' do
          should 'assign the uncompleted maintenances with status OK' do
            FactoryGirl.create(:maintenance, device: @account_device, completed_at: Time.now, target_mileage: 101)
            FactoryGirl.create(:maintenance, device: @account_device)
            FactoryGirl.create(:maintenance, device: @account_device, target_mileage: 101)
            FactoryGirl.create(:maintenance, device: @account_device, scheduled_time: Time.now + 9.days)
            FactoryGirl.create(:maintenance, device: @account_device, scheduled_time: Time.now + 11.days)

            get :index, { status: Maintenance::STATUS_OK.to_s }

            assert_equal(2, assigns(:maintenances).length)
          end
        end

        context 'when status is PENDING' do
          should 'assign the uncompleted maintenances with status PENDING' do
            FactoryGirl.create(:maintenance, device: @account_device, completed_at: Time.now, target_mileage: 26)
            FactoryGirl.create(:maintenance, device: @account_device, target_mileage: 26)
            FactoryGirl.create(:maintenance, device: @account_device, target_mileage: 25)
            FactoryGirl.create(:maintenance, device: @account_device, scheduled_time: Time.now + 9.days)
            FactoryGirl.create(:maintenance, device: @account_device, scheduled_time: Time.now)

            get :index, { status: Maintenance::STATUS_PENDING.to_s }

            assert_equal(2, assigns(:maintenances).length)
          end
        end

        context 'when status is DUE' do
          should 'assign the uncompleted maintenances with status DUE' do
            FactoryGirl.create(:maintenance, device: @account_device, completed_at: Time.now, target_mileage: 24)
            FactoryGirl.create(:maintenance, device: @account_device, target_mileage: 0)
            FactoryGirl.create(:maintenance, device: @account_device, target_mileage: 24)
            FactoryGirl.create(:maintenance, device: @account_device, target_mileage: 26)
            FactoryGirl.create(:maintenance, device: @account_device, scheduled_time: Time.now + 1.day, target_mileage: 0)
            FactoryGirl.create(:maintenance, device: @account_device, scheduled_time: Time.now - 1.day, target_mileage: 0)
            FactoryGirl.create(:maintenance, device: @account_device, scheduled_time: Time.now + 2.days, target_mileage: 0)

            get :index, { status: Maintenance::STATUS_DUE.to_s }

            assert_equal(2, assigns(:maintenances).length)
          end
        end

        context 'when status is PDUE' do
          should 'assign the uncompleted maintenances with status PDUE' do
            FactoryGirl.create(:maintenance, device: @account_device, completed_at: Time.now, target_mileage: 0.6)
            FactoryGirl.create(:maintenance, device: @account_device, target_mileage: 0.6)
            FactoryGirl.create(:maintenance, device: @account_device, scheduled_time: Time.now - 2.days)

            get :index, { status: Maintenance::STATUS_PDUE.to_s }

            assert_equal(2, assigns(:maintenances).length)
          end
        end
      end

      context 'when mileage is sent as a param' do
        should 'assign the maintenances with the given mileage' do
          FactoryGirl.create(:maintenance, device: @account_device, mileage: 30)
          FactoryGirl.create(:maintenance, device: @account_device, mileage: 40)
          FactoryGirl.create(:maintenance, device: @account_device, mileage: 40)

          get :index, { mileage: 40 }

          assert_equal(2, assigns(:maintenances).length)
        end
      end
    end
  end

  context 'GET new' do
    context 'when unauthorized' do
      should 'redirect to login page' do
        get :index

        assert_redirected_to '/user/sign_in'
      end
    end

    context 'when authorized' do
      setup do
        @user = FactoryGirl.create(:user)
        @account_device = FactoryGirl.create(:device, account: @user.account)

        sign_in @user
      end

      should 'assign variable devices with account provisioned devices' do
        device_one = FactoryGirl.create(:device, account: @user.account)
        device_two = FactoryGirl.create(:device, account: @user.account)

        get :new

        assert_equal(3, assigns(:devices).length)
      end

      should 'render template new' do
        get :new

        assert_template :new
      end

      should 'assign variable maintenance' do
        get :new

        assert assigns(:maintenance)
      end
    end
  end

  context 'POST create' do
    context 'when unauthorized' do
      should 'redirect to login page' do
        post :create

        assert_redirected_to '/user/sign_in'
      end
    end

    context 'when authorized' do
      setup do
        @user = FactoryGirl.create(:user)
        @account_device = FactoryGirl.create(:device, account: @user.account)

        sign_in @user
      end

      context 'when maintenance type is scheduled' do
        context 'when response is success' do
          should 'create a new scheduled maintenance' do
            assert_difference 'Maintenance.count', 1 do
              post :create, { maintenance: { device_id: @account_device.id, description_task: 'Maintenance Test', type_task: Maintenance::SCHEDULED_TYPE, scheduled_time: Time.now } }
            end
          end

          should 'redirect to action index' do
            post :create, { maintenance: { device_id: @account_device.id, description_task: 'Maintenance Test', type_task: Maintenance::SCHEDULED_TYPE, scheduled_time: Time.now } }

            assert_redirected_to action: 'index'
          end
        end

        context 'when response is an error' do
          should 'display a flash error message' do
            post :create, { maintenance: { device_id: @account_device.id, type_task: Maintenance::SCHEDULED_TYPE, scheduled_time: Time.now } }

            assert flash[:error]
          end

          should 'render template new' do
            post :create, { maintenance: { device_id: @account_device.id, type_task: Maintenance::SCHEDULED_TYPE, scheduled_time: Time.now } }

            assert_template :new
          end
        end
      end

      context 'when maintenance type is mileage' do
        context 'when response is success' do
          should 'create a new mileage maintenance' do
            assert_difference 'Maintenance.count', 1 do
              post :create, { maintenance: { device_id: @account_device.id, description_task: 'Maintenance Test', type_task: Maintenance::MILEAGE_TYPE, mileage: 10 } }
            end
          end

          should 'redirect to action index' do
            post :create, { maintenance: { device_id: @account_device.id, description_task: 'Maintenance Test', type_task: Maintenance::MILEAGE_TYPE, mileage: 10 } }

            assert_redirected_to action: 'index'
          end
        end

        context 'when response is an error' do
          should 'display a flash error message' do
            post :create, { maintenance: { device_id: @account_device.id, type_task: Maintenance::MILEAGE_TYPE, mileage: 10 } }

            assert flash[:error]
          end

          should 'render template new' do
            post :create, { maintenance: { device_id: @account_device.id, type_task: Maintenance::MILEAGE_TYPE, mileage: 10 } }

            assert_template :new
          end
        end
      end
    end
  end

  context 'GET show' do
    context 'when unauthorized' do
      should 'redirect to login page' do
        get :show, { id: 1 }

        assert_redirected_to '/user/sign_in'
      end
    end

    context 'when authorized' do
      setup do
        @user = FactoryGirl.create(:user)
        @account_device = FactoryGirl.create(:device, account: @user.account)

        sign_in @user
      end

      context 'when given maintenance id exists' do
        should 'render template show' do
          maintenance = FactoryGirl.create(:maintenance, device: @account_device)

          get :show, { id: maintenance.id }

          assert_template :show
        end
      end

      context 'when maintenance does not exist' do
        setup do
          get :show, { id: 1 }
        end

        should 'show an error flash message' do
          assert_equal(" Maintenance could not be found. ", flash[:error])
        end

        should 'redirect to action index' do
          assert_redirected_to action: 'index'
        end
      end
    end
  end

  context 'DELETE destroy' do
    context 'when unauthorized' do
      should 'redirect to login page' do
        delete :destroy, { id: 1 }

        assert_redirected_to '/user/sign_in'
      end
    end

    context 'when authorized' do
      setup do
        @user = FactoryGirl.create(:user)
        @account_device = FactoryGirl.create(:device, account: @user.account)

        sign_in @user
      end

      context 'when given maintenance id exists' do
        context 'when response is success' do
          setup do
            @maintenance = FactoryGirl.create(:maintenance, device: @account_device)
          end

          should 'redirect to action index' do
            delete :destroy, { id: @maintenance.id }

            assert_redirected_to action: 'index'
          end

          should 'show a success flash message' do
            delete :destroy, { id: @maintenance.id }

            assert_equal(' Maintenance task was successfully deleted. ', flash[:success])
          end
        end

        context 'when response is error' do
          setup do
            @maintenance = FactoryGirl.create(:maintenance, device: @account_device)

            Maintenance.any_instance.stubs(:destroy).returns(false)

            delete :destroy, { id: @maintenance.id }
          end

          should 'show an error flash message' do
            assert_equal(' Error deleting Maintenance task. ', flash[:error])
          end

          should 'redirect to action show' do
            assert_redirected_to "/maintenances/#{@maintenance.id}"
          end
        end
      end

      context 'when maintenance does not exist' do
        setup do
          delete :destroy, { id: 1 }
        end

        should 'show an error flash message' do
          assert_equal(' Maintenance could not be found. ', flash[:error])
        end

        should 'redirect to action index' do
          assert_redirected_to action: 'index'
        end
      end
    end
  end

  context 'POST reset' do
    context 'when unauthorized' do
      should 'redirect to login page' do
        post :reset, { id: 1 }

        assert_redirected_to '/user/sign_in'
      end
    end

    context 'when authorized' do
      setup do
        @user = FactoryGirl.create(:user)
        @account_device = FactoryGirl.create(:device, account: @user.account)

        sign_in @user
      end

      context 'when given maintenance id exists' do
        context 'when response is success' do
          setup do
            @maintenance = FactoryGirl.create(:maintenance, device: @account_device)
          end

          context 'when maintenance is scheduled' do
            should 'create a new maintenance' do
              assert_difference 'Maintenance.count', 1 do
                post :reset, { id: @maintenance.id, maintenance: { type_task: Maintenance::SCHEDULED_TYPE, mileage: 10, scheduled_time: Time.now, description_task: 'Maintenance Test' } }
              end
            end

            should 'display a success flash message' do
              post :reset, { id: @maintenance.id, maintenance: { type_task: Maintenance::SCHEDULED_TYPE, mileage: 10, scheduled_time: Time.now, description_task: 'Maintenance Test' } }

              assert_equal(' Maintenance task was successfully completed. ', flash[:success])
            end

            should 'redirect to action show' do
              post :reset, { id: @maintenance.id, maintenance: { type_task: Maintenance::SCHEDULED_TYPE, mileage: 10, scheduled_time: Time.now, description_task: 'Maintenance Test' } }

              last_maintenance = Maintenance.last

              assert_redirected_to "/maintenances/#{last_maintenance.id}"
            end
          end

          context 'when maintenance is mileage' do
            should 'create a new maintenance' do
              assert_difference 'Maintenance.count', 1 do
                post :reset, { id: @maintenance.id, maintenance: { type_task: Maintenance::MILEAGE_TYPE, mileage: 10, scheduled_time: Time.now, description_task: 'Maintenance Test' } }
              end
            end

            should 'display a success flash message' do
              post :reset, { id: @maintenance.id, maintenance: { type_task: Maintenance::MILEAGE_TYPE, mileage: 10, scheduled_time: Time.now, description_task: 'Maintenance Test' } }

              assert_equal(' Maintenance task was successfully completed. ', flash[:success])
            end

            should 'redirect to action show' do
              post :reset, { id: @maintenance.id, maintenance: { type_task: Maintenance::MILEAGE_TYPE, mileage: 10, scheduled_time: Time.now, description_task: 'Maintenance Test' } }

              last_maintenance = Maintenance.last

              assert_redirected_to "/maintenances/#{last_maintenance.id}"
            end
          end
        end

        context 'when response is error' do
          setup do
            @maintenance = FactoryGirl.create(:maintenance, device: @account_device)

            Maintenance.any_instance.stubs(:save).returns(false)

            post :reset, { id: @maintenance.id, maintenance: { type_task: Maintenance::MILEAGE_TYPE, mileage: 10, scheduled_time: Time.now, description_task: 'Maintenance Test' } }
          end

          should 'redirect to action show' do
            assert_redirected_to "/maintenances/#{@maintenance.id}"
          end

          should 'display an error flash message' do
            assert_equal(' Error reseting Maintenance task. ', flash[:error])
          end
        end
      end

      context 'when maintenance does not exist' do
        setup do
          post :reset, { id: 1 }
        end

        should 'show an error flash message' do
          assert_equal(' Maintenance could not be found. ', flash[:error])
        end

        should 'redirect to action index' do
          assert_redirected_to action: 'index'
        end
      end
    end
  end

  context 'POST complete' do
    context 'when unauthorized' do
      should 'redirect to login page' do
        post :complete, { id: 1 }

        assert_redirected_to '/user/sign_in'
      end
    end

    context 'when authorized' do
      setup do
        @user = FactoryGirl.create(:user)
        @account_device = FactoryGirl.create(:device, account: @user.account)

        sign_in @user
      end

      context 'when given maintenance id exists' do
        context 'when maintenance is not completed' do
          setup do
            @maintenance = FactoryGirl.create(:maintenance, device: @account_device)
          end

          should 'complete the maintenance' do
            post :complete, { id: @maintenance.id }

            completed_maintenance = Maintenance.find_by(id: @maintenance.id)

            assert completed_maintenance.is_completed?
          end

          should 'display a success flash message' do
            post :complete, { id: @maintenance.id }

            assert_equal(' Maintenance task was successfully completed. ', flash[:success])
          end

          should 'redirect to action show' do
            post :complete, { id: @maintenance.id }

            assert_redirected_to "/maintenances/#{@maintenance.id}"
          end
        end

        context 'when maintenance is already completed' do
          setup do
            @maintenance = FactoryGirl.create(:maintenance, device: @account_device, completed_at: Time.now)

            post :complete, { id: @maintenance.id }
          end

          should 'redirect to action show' do
            assert_redirected_to "/maintenances/#{@maintenance.id}"
          end

          should 'display an error flash message' do
            assert_equal(' Maintenance task was already completed. ', flash[:error])
          end
        end

        context 'when response is error' do
          setup do
            @maintenance = FactoryGirl.create(:maintenance, device: @account_device)

            Maintenance.any_instance.stubs(:save).returns(false)

            post :complete, { id: @maintenance.id }
          end

          should 'redirect to action show' do
            assert_redirected_to "/maintenances/#{@maintenance.id}"
          end

          should 'display an error flash message' do
            assert_equal(' Error completing Maintenance task. ', flash[:error])
          end
        end
      end

      context 'when maintenance does not exist' do
        setup do
          post :complete, { id: 1 }
        end

        should 'show an error flash message' do
          assert_equal(' Maintenance could not be found. ', flash[:error])
        end

        should 'redirect to action index' do
          assert_redirected_to action: 'index'
        end
      end
    end
  end
end
