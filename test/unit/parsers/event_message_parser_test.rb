require 'test_helper'

class EventMessageParserTest < ActiveSupport::TestCase
  context '.parse' do
    context 'when receiving an event_type thing' do
      setup do
        Device.delete_all
        EventState::Base.reset_cache
        collection_token = 'test-coll-token'
        @account = FactoryGirl.create(:account, collection_token: collection_token)
        @thing_token = 'test-thing-token'
        @new_name_label = 'new-test-name'
        @event_message = {
          type: {
            action: 'thing'
          },
          time: "2017-05-09T21:34:14.794Z",
          thing: {
            thing_token: @thing_token,
            label: "GPS device",
            collection_token: collection_token,
            identities: [{
              type: 'IMEI',
              value: '0000'
            }]
          }
        }
      end

      context 'when collection_token matches an account' do
        context 'when thing token does not match' do
          context 'when imei does not match a device' do
            should 'create a new device in the matching account' do
              assert_difference -> { Device.count }, 1 do
                EventMessageParser.parse(JSON.dump(@event_message))
              end

              device = Device.find_by(thing_token: @thing_token)
              assert_equal 'GPS device', device.name
              assert_equal ProvisionStatus::STATUS_ACTIVE, device.provision_status_id
              assert_equal @account.id, device.account_id
            end
          end

          context 'when imei matches a device' do
            setup do
              @event_message[:thing][:thing_token] = "#{@thing_token}-2"
            end

            should 'update the device that matches the given imei with the new token' do
              device = FactoryGirl.create(:device, thing_token: @thing_token, imei: '0000')

              assert_no_difference -> { Device.count } do
                EventMessageParser.parse(JSON.dump(@event_message))
              end

              device = Device.find_by(imei: '0000')
              assert_equal "#{@thing_token}-2", device.thing_token
              assert_equal @account.id, device.account_id
            end
          end
        end

        context 'when thing token exists' do
          setup do
            @event_message[:thing][:deleted] = 'true'
            @event_message[:thing][:label] = @new_name_label
          end

          should 'update the device that matches the given token and the device account' do
            device = FactoryGirl.create(:device, name: 'old_name', thing_token: @thing_token, provision_status_id: ProvisionStatus::STATUS_ACTIVE)

            assert_no_difference -> { Device.count } do
              EventMessageParser.parse(JSON.dump(@event_message))
            end

            device = Device.find_by(thing_token: @thing_token)
            assert_equal @new_name_label, device.name
            assert_equal ProvisionStatus::STATUS_DELETED, device.provision_status_id
            assert_equal @account.id, device.account_id
          end
        end
      end

      context 'when collection_token does not match an account' do
        setup do
          other_collection_token = 'other-coll-token'
          @event_message[:thing][:collection_token] = other_collection_token
        end

        context 'when thing token does not exist' do
          should 'create a new device with no account' do
            assert_difference -> { Device.count }, 1 do
              EventMessageParser.parse(JSON.dump(@event_message))
            end

            device = Device.find_by(thing_token: @thing_token)
            assert_equal 'GPS device', device.name
            assert_equal ProvisionStatus::STATUS_INACTIVE, device.provision_status_id
            assert_equal 0, device.account_id
          end
        end

        context 'when thing token exists' do
          setup do
            @event_message[:thing][:deleted] = 'true'
            @event_message[:thing][:label] = @new_name_label
          end

          should 'update the device that matches the given token and does not change accounts' do
            device = FactoryGirl.create(:device, name: 'old_name', thing_token: @thing_token, provision_status_id: ProvisionStatus::STATUS_ACTIVE)
            old_account_id = device.account_id

            assert_no_difference -> { Device.count } do
              EventMessageParser.parse(JSON.dump(@event_message))
            end

            device = Device.find_by(thing_token: @thing_token)
            assert_equal @new_name_label, device.name
            assert_equal ProvisionStatus::STATUS_DELETED, device.provision_status_id
            assert_equal 0, device.account_id
          end
        end
      end
    end

    context 'when receiving an event_type message' do
      setup do
        Device.delete_all
        Reading.delete_all
        EventState::Base.reset_cache
        @thing_token = 'test-thing-token'

        @event_message = {
          time: "2017-05-09T21:34:14.794Z",
          messages: [{
            v: 1,
            seq: 1,
            tmrpt: "2017-05-09T21:34:14.794Z",
            gps: {
              hdop: 3,
              lat: 92.99,
              lng: 92.99,
            }
          }],
          type: {
            action: "log"
          },
          thing: {
            thing_token: @thing_token,
            label: "GPS device",
            collection_token: 'test-coll-token',
            identities: [{
              type: 'IMEI',
              value: '0000'
            }]
          }
        }
      end

      context 'when given token was found' do
        setup do
          FactoryGirl.create(:device, thing_token: @thing_token)
        end

        context 'with lon field in gps attr' do
          should 'create a new reading with longitude' do
            assert_difference -> { Reading.count }, 1 do
              EventMessageParser.parse(JSON.dump(@event_message))
            end
            assert Reading.last.longitude
          end
        end

        context 'with lng field in gps attr' do
          should 'create a new reading with longitude' do
            assert_difference -> { Reading.count }, 1 do
              EventMessageParser.parse(JSON.dump(@event_message))
            end
            assert Reading.last.longitude
          end
        end

        should 'update the device reading fields' do
          EventMessageParser.parse(JSON.dump(@event_message))
          reading = Reading.last

          device = Device.find_by(thing_token: @thing_token)
          assert_equal reading.id, device.last_reading_id
          assert_equal reading.id, device.last_gps_reading_id
          assert_equal reading.recorded_at, device.last_online_time
        end

        should 'not update last_gps_reading_id if no gps data given' do
          @event_message[:messages][0][:gps] = nil
          EventMessageParser.parse(JSON.dump(@event_message))
          reading = Reading.last

          assert_nil Device.find_by(thing_token: @thing_token).last_gps_reading_id
        end
      end

      context 'when given token was not found' do
        setup do
          EventState::Base.reset_cache
        end

        should 'ignore the reading' do
          assert_no_difference -> { Reading.count } do
            EventMessageParser.parse(JSON.dump(@event_message))
          end
        end
      end
    end
  end
end
