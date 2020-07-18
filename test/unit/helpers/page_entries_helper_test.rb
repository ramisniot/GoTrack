require 'test_helper'

class PageEntriesHelperTest < ActionView::TestCase
  context 'page entries method' do
    context 'for collection with more than one page' do
      setup do
        @d1 = Device.create(name: 'Dev1', imei: 111)
        @d2 = Device.create(name: 'Dev2', imei: 112)
        @d3 = Device.create(name: 'Dev3', imei: 113)
        @arr = [@d1, @d2, @d3].paginate(page: 1, per_page: 2)
      end

      should 'return message for first page' do
        assert_match /Devices \(1&nbsp;-&nbsp;2 of 3\)/, page_entries(@arr, {})
      end
    end

    context 'for collection with more than one element' do
      setup do
        @d1 = Device.create(name: 'Dev1', imei: 111)
        @d2 = Device.create(name: 'Dev2', imei: 112)
        @arr = [@d1, @d2].paginate(page: 1)
      end

      should 'return message for total entries' do
        assert_match /Devices \(1&nbsp;-&nbsp;2 of 2\)/, page_entries(@arr, {})
      end
    end

    context 'for collection one element' do
      setup do
        @d1 = Device.create(name: 'Dev1', imei: 111)
        @arr = [@d1].paginate(page: 1)
      end

      should 'return message for 1 element as total' do
        assert_match /Devices \(1 total\)/, page_entries(@arr, {})
      end
    end

    context 'for empty collection' do
      setup do
        @arr = [].paginate(page: 1)
      end

      should 'message for empty collection' do
        assert_match /Entries \(0 total\)/, page_entries(@arr, {})
      end
    end
  end
end
