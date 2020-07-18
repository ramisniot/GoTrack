require 'net/http'
require 'uri'

module QiotApi
  STATUS_CODES = Rack::Utils::SYMBOL_TO_STATUS_CODE
  QIOT_API_SERVER_ERROR = 'Server error. Contact system admin.'.freeze
  QIOT_API_AUTH_ERROR = 'Could not authenticate. Contact system admin.'.freeze
  QIOT_SYNC_ERROR_MSG = 'Could not sync account. Contact system admin.'.freeze
  QIOT_CONNECTION_ERROR_MSG = 'Connection error. Contact system admin.'.freeze
  QIOT_COLLECTIONS_URL = "#{QIOT_USER_SERVICE_URL}/accounts/#{QIOT_ACCOUNT_TOKEN_IDENTIFIER}/collections".freeze
  QIOT_THINGS_URL = "#{QIOT_USER_SERVICE_URL}/accounts/#{QIOT_ACCOUNT_TOKEN_IDENTIFIER}/things".freeze
  QIOT_API_TOKEN_URL = "#{QIOT_USER_SERVICE_URL}/signin-app".freeze
  QIOT_REVERSE_GEOCODING_URL = "#{QIOT_GEOCODING_SERVICE_URL}/geo/reverse".freeze
  METHODS = {
    get: Net::HTTP::Get,
    post: Net::HTTP::Post,
    patch: Net::HTTP::Patch,
    delete: Net::HTTP::Delete
  }.freeze

  class << self
    @@qiot_api_token = ''

    def apply_reverse_geocoding(body)
      generic_request(body, QIOT_REVERSE_GEOCODING_URL, :get)
    end

    def create_collection(body)
      generic_request(body, QIOT_COLLECTIONS_URL, :post)
    end

    def update_collection(body, collection_token)
      url = build_entity_url(QIOT_COLLECTIONS_URL, collection_token)
      generic_request(body, url, :patch)
    end

    def delete_collection(collection_token)
      url = build_entity_url(QIOT_COLLECTIONS_URL, collection_token)
      generic_request('', url, :delete)
    end

    def create_thing(body)
      generic_request(body, QIOT_THINGS_URL, :post)
    end

    def update_thing(body, thing_token)
      url = build_entity_url(QIOT_THINGS_URL, thing_token, '/sync')
      generic_request(body, url, :patch)
    end

    def set_token(api_token)
      @@qiot_api_token = api_token
    end

    def get_token
      @@qiot_api_token
    end

    private

    def generic_request(body, url, method, refresh_token = true)
      ENABLE_QIOT_SYNC ?
        generic_real_request(body, url, method, refresh_token) :
        generic_fake_request(url, body)
    end

    def generic_fake_request(url, body)
      data = {}
      if url.match(/#{QIOT_COLLECTIONS_URL}/)
        data[:collection] = {}
      elsif url.match(/#{QIOT_THINGS_URL}/)
        data[:thing] = {}
      end

      { success: true, data: data }
    end

    def generic_real_request(body, url, method, refresh_token)
      request_api_token if invalid_api_token

      return { success: false, error: QIOT_API_AUTH_ERROR } if invalid_api_token

      headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{@@qiot_api_token}"
      }

      response = make_request(body, url, headers, method)

      case response.code
        when STATUS_CODES[:ok].to_s
          { success: true, data: JSON.parse(response.body) }
        when STATUS_CODES[:unauthorized].to_s
          return { success: false, error: QIOT_API_AUTH_ERROR } unless refresh_token
          Rails.logger.info("UNAUTHORIZED. Requesting new api token...")
          set_token nil
          generic_request(body, url, method, false)
        when STATUS_CODES[:internal_server_error].to_s
          Rails.logger.error("Server error on resquest to #{url}, response was: #{response.body}")
          { success: false, error: QIOT_API_SERVER_ERROR }
        else
          Rails.logger.error("Error on resquest to #{url}, responded with #{response.code}, message: #{response.body}")
          error_message = JSON.parse(response.body)['error']['message'] rescue 'See logs'
          { success: false, error: error_message }
      end
    rescue Errno::ECONNREFUSED
      Rails.logger.error("Could not connect to #{url}")
      { success: false, error: "Could not connect to #{url}. Contact system admin." }
    end

    def invalid_api_token
      @@qiot_api_token.nil? || @@qiot_api_token.empty?
    end

    def request_api_token
      response = get_api_token
      @@qiot_api_token = response['token'] if response['status'] == 'success'
    end

    def get_api_token
      body = JSON.dump({ account_token: QIOT_IO_API_TOKEN })
      headers = { 'Content-Type': 'application/json' }

      begin
        response = make_request(body, QIOT_API_TOKEN_URL, headers, :post)

        if (response.code != STATUS_CODES[:ok].to_s)
          Rails.logger.error("Could not sign in with #{QIOT_API_TOKEN_URL}, error: #{response.body}")
          { error: QIOT_SYNC_ERROR_MSG }
        else
          JSON.parse(response.body)
        end
      rescue Errno::ECONNREFUSED
        Rails.logger.error("Could not connect to #{QIOT_API_TOKEN_URL}")
        { error: QIOT_CONNECTION_ERROR_MSG }
      end
    end

    def make_request(body, url, headers, method)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if QIOT_SSL

      case method
      when :get
        full_path = path_with_params(uri.request_uri, JSON.parse(body))
        request = METHODS[method].new(full_path)
      else
        request = METHODS[method].new(uri.request_uri)
        request.body = body
      end
      headers.each do |key, value|
        request[key] = value
      end
      http.request(request)
    end

    def path_with_params(url, params)
      encoded_params = URI.encode_www_form(params)
      [url, encoded_params].join('?')
    end

    def build_entity_url(url, identifier, url_ending = '')
      "#{url}/#{identifier}#{url_ending}"
    end
  end
end
