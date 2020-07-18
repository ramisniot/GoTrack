require 'test_helper'

class OneTimeReportsHelperTest < ActionView::TestCase
  fixtures :accounts

  context 'groups_options' do
    setup do
      options = ''
      current_account.groups.each do |group|
        options << "\n" unless options.empty?
        options << "<option value=\"#{group.id}\">#{group.name}</option>"
      end
      @options = "<option value=\"0\">Default</option>#{options}"
    end

    should 'return the groups properly' do
      assert_equal @options, groups_options
    end
  end

  def current_account
    @current_account = Account.find(1)
  end
end
