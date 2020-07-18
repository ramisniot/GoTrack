module OneTimeReportsHelper
  def groups_options
    '<option value="0">Default</option>'.html_safe + options_from_collection_for_select(current_account().groups, 'id', 'name')
  end
end
