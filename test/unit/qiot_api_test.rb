require 'net/http'
require 'test_helper'

class QiotApiTest < ActiveSupport::TestCase
  setup do
    @api_token_request_body = JSON.dump(account_token: QIOT_IO_API_TOKEN)
    @api_token_request_headers = { 'Content-Type': 'application/json' }
    @api_token = 'API-TOKEN-TEST'
    @status_codes = Rack::Utils::SYMBOL_TO_STATUS_CODE
  end

  context 'apply_reverse_geocoding' do
    setup do
      @rg_request_params = JSON.dump(lat: 11.1, lng: 11.1)
      @rg_request_response = JSON.dump(city: 'test-city', postal_code: 'test-zip', country_long: 'test-country', address: 'test-address', route: 'test-route')
      @rg_request_headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{@api_token}"
      }
    end

    context 'when api token is not set' do
      context 'when responds with success' do
        setup do
          api_token_response = mock
          reverse_geocoding_response = mock

          QiotApi.stubs(:make_request)
                 .with(@api_token_request_body, QiotApi::QIOT_API_TOKEN_URL, @api_token_request_headers, :post)
                 .once
                 .returns(api_token_response)

          QiotApi.stubs(:make_request)
                 .with(@rg_request_params, QiotApi::QIOT_REVERSE_GEOCODING_URL, @rg_request_headers, :get)
                 .once
                 .returns(reverse_geocoding_response)

          api_token_response.stubs(:code).returns(@status_codes[:ok].to_s)
          api_token_response.stubs(:body).returns(JSON.dump(status: 'success', token: @api_token))

          reverse_geocoding_response.stubs(:code).returns(@status_codes[:ok].to_s)
          reverse_geocoding_response.stubs(:body).returns(@rg_request_response)

          QiotApi.apply_reverse_geocoding(@rg_request_params)
        end

        teardown do
          QiotApi.set_token('')
        end

        should 'set the requested token' do
          assert_equal @api_token, QiotApi.get_token
        end
      end

      context 'when responds with an error' do
        setup do
          api_token_response = mock

          QiotApi.stubs(:make_request)
                 .with(@api_token_request_body, QiotApi::QIOT_API_TOKEN_URL, @api_token_request_headers, :post)
                 .once
                 .returns(api_token_response)

          api_token_response.stubs(:code).returns(@status_codes[:internal_server_error].to_s)
          api_token_response.stubs(:body).returns(JSON.dump(status: 'error', token: @api_token))

          @response = QiotApi.apply_reverse_geocoding(@rg_request_params)
        end

        teardown do
          QiotApi.set_token('')
        end

        should 'return error on request to QIOT' do
          assert_equal 'Could not authenticate. Contact system admin.', @response[:error]
        end

        should 'not set the requested token' do
          assert_equal '', QiotApi.get_token
        end
      end
    end

    context 'when api token is set' do
      setup do
        QiotApi.set_token @api_token
        response = mock
        QiotApi.stubs(:make_request)
               .with(@rg_request_params, QiotApi::QIOT_REVERSE_GEOCODING_URL, @rg_request_headers, :get)
               .once
               .returns(response)

        response.stubs(:code).returns(@status_codes[:ok].to_s)
        response.stubs(:body).returns(@rg_request_response)
      end

      teardown do
        QiotApi.set_token ''
      end

      should 'make only one request to QIOT' do
        QiotApi.apply_reverse_geocoding(@rg_request_params)
      end
    end
  end

  context 'create_collection' do
    setup do
      @delivery_request_params = JSON.dump({ name: 'test' })
      @delivery_request_response = JSON.dump({ collection: { collection_token: 'token' } })
      @delivery_request_headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{@api_token}"
      }
    end

    context 'when api token is not set' do
      context 'when responds with success' do
        setup do
          api_token_response = mock
          delivery_response = mock

          QiotApi.stubs(:make_request)
                 .with(@api_token_request_body, QiotApi::QIOT_API_TOKEN_URL, @api_token_request_headers, :post)
                 .once
                 .returns(api_token_response)
          QiotApi.stubs(:make_request)
                 .with(@delivery_request_params, QiotApi::QIOT_COLLECTIONS_URL, @delivery_request_headers, :post)
                 .once
                 .returns(delivery_response)

          api_token_response.stubs(:code).returns(@status_codes[:ok].to_s)
          api_token_response.stubs(:body).returns(JSON.dump({ status: 'success', token: @api_token }))
          delivery_response.stubs(:code).returns(@status_codes[:ok].to_s)
          delivery_response.stubs(:body).returns(@delivery_request_response)
          QiotApi.create_collection(@delivery_request_params)
        end

        teardown do
          QiotApi.set_token('')
        end

        should 'set the obtained token' do
          assert_equal @api_token, QiotApi.get_token
        end
      end

      context 'when responds with error' do
        setup do
          api_token_response = mock
          QiotApi.stubs(:make_request)
                 .with(@api_token_request_body, QiotApi::QIOT_API_TOKEN_URL, @api_token_request_headers, :post)
                 .once
                 .returns(api_token_response)
          api_token_response.stubs(:code).returns(@status_codes[:internal_server_error].to_s)
          api_token_response.stubs(:body).returns(JSON.dump({ status: 'error', token: @api_token }))
          @response = QiotApi.create_collection(@delivery_request_params)
        end

        teardown do
          QiotApi.set_token('')
        end

        should 'return error on request to QIOT' do
          assert_equal QiotApi::QIOT_API_AUTH_ERROR, @response[:error]
        end

        should 'not set the obtained token' do
          assert_equal '', QiotApi.get_token
        end
      end
    end

    context 'when api token is set' do
      setup do
        QiotApi.set_token @api_token
        response = mock
        QiotApi.stubs(:make_request)
               .with(@delivery_request_params, QiotApi::QIOT_COLLECTIONS_URL, @delivery_request_headers, :post)
               .once
               .returns(response)
        response.stubs(:code).returns(@status_codes[:ok].to_s)
        response.stubs(:body).returns(@delivery_request_response)
      end

      teardown do
        QiotApi.set_token ''
      end

      should 'make only one request to QIOT' do
        QiotApi.create_collection(@delivery_request_params)
      end
    end
  end

  context 'create_thing' do
    setup do
      @delivery_request_params = JSON.dump({ name: 'test', imei: '1234', collection_token: 'collection_token' })
      @delivery_request_response = JSON.dump({ thing: { thing_token: 'token' } })
      @delivery_request_headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{@api_token}"
      }
    end

    context 'when api token is not set' do
      context 'and responds with success' do
        setup do
          api_token_response = mock
          delivery_response = mock

          QiotApi.stubs(:make_request)
                 .with(@api_token_request_body, QiotApi::QIOT_API_TOKEN_URL, @api_token_request_headers, :post)
                 .once
                 .returns(api_token_response)
          QiotApi.stubs(:make_request)
                 .with(@delivery_request_params, QiotApi::QIOT_THINGS_URL, @delivery_request_headers, :post)
                 .once
                 .returns(delivery_response)

          api_token_response.stubs(:code).returns(@status_codes[:ok].to_s)
          api_token_response.stubs(:body).returns(JSON.dump({ status: 'success', token: @api_token }))
          delivery_response.stubs(:code).returns(@status_codes[:ok].to_s)
          delivery_response.stubs(:body).returns(@delivery_request_response)
          QiotApi.create_thing(@delivery_request_params)
        end

        teardown do
          QiotApi.set_token('')
        end

        should 'set the obtained token' do
          assert_equal @api_token, QiotApi.get_token
        end
      end

      context 'when responds with 500 error' do
        setup do
          api_token_response = mock
          QiotApi.stubs(:make_request)
                 .with(@api_token_request_body, QiotApi::QIOT_API_TOKEN_URL, @api_token_request_headers, :post)
                 .once
                 .returns(api_token_response)
          api_token_response.stubs(:code).returns(@status_codes[:internal_server_error].to_s)
          api_token_response.stubs(:body).returns(JSON.dump({ status: 'error', token: @api_token }))
          @response = QiotApi.create_thing(@delivery_request_params)
        end

        teardown do
          QiotApi.set_token('')
        end

        should 'return error on request to QIOT' do
          assert_equal QiotApi::QIOT_API_AUTH_ERROR, @response[:error]
        end

        should 'not set the obtained token' do
          assert_equal '', QiotApi.get_token
        end
      end

    end

    context 'when api token is set' do
      setup do
        QiotApi.set_token @api_token
        @response = mock
        QiotApi.expects(:make_request)
          .with(@delivery_request_params, QiotApi::QIOT_THINGS_URL, @delivery_request_headers, :post)
          .once
          .returns(@response)
      end

      teardown do
        QiotApi.set_token ''
      end

      context 'when request succeeds' do
        setup do
          @response.stubs(:code).returns(@status_codes[:ok].to_s)
          @response.stubs(:body).returns(@delivery_request_response)

          @result = QiotApi.create_thing(@delivery_request_params)
        end

        should 'return success as true' do
          assert @result[:success]
        end

        should 'return data in the response' do
          assert_equal(JSON.parse(@delivery_request_response), @result[:data])
        end
      end

      context 'when request fails with non 500 error' do
        setup do
          error_response_json = {
            status: "error",
            error: { key: "ModelInvalidError", message: "Value can not be blank" }
          }

          @response.stubs(:code).returns(@status_codes[:unprocessable_entity].to_s)
          @response.stubs(:body).returns(error_response_json.to_json)

          @result = QiotApi.create_thing(@delivery_request_params)
        end

        teardown do
          QiotApi.set_token('')
        end

        should 'return success as false' do
          refute @result[:success]
        end

        should 'return error message' do
          assert_equal("Value can not be blank", @result[:error])
        end
      end
    end
  end
end
