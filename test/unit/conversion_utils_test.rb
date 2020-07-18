require 'test_helper'

class ConversionUtilsTest < ActiveSupport::TestCase
  context 'km_to_miles' do
    context 'when km is nil' do
      should 'return nil' do
        assert_nil ConversionUtils.km_to_miles(nil)
      end
    end

    context 'when km is not nil' do
      should 'convert kilometers to miles' do
        assert_equal ConversionUtils::KM_TO_MILES, ConversionUtils.km_to_miles(1)
      end
    end
  end
end