
Rails.application.config.assets.precompile += (
  Dir[Rails.root + 'app/assets/javascripts/*.{js,js.erb}'] +
  Dir[Rails.root + 'app/assets/stylesheets/*.css']
).collect { |path| File.basename(path) }

# Version of your assets, change this if you want to expire all your assets
Rails.application.config.assets.version = '1.1'
