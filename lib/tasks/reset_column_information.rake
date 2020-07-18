task :reset_column_information do |t|
  ActiveRecord::Base.descendants.map(&:reset_column_information)
end
