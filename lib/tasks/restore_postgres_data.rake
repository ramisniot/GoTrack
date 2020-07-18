namespace :gotrack do
  desc 'restore a postgres PGDMP file into the environment'
  task restore_postgres_data: :environment do
    raise 'must not be run in production' if Rails.env.production?
    raise 'PGDMP file not provided' unless pgdmp_filename = ENV['PGDMP']
    raise "PGDMP file does not exist: #{pgdmp_filename}" unless File.exists?(pgdmp_filename)

    config = YAML.load_file('config/database.yml')[Rails.env] || {}
    database_name = config['database']
    database_user = config['username']
    database_pass = config['password']
    raise 'could not find database configuration' unless database_name and database_user

    password_env = "PGPASSWORD=#{database_pass} " if (database_pass)

    Rake::Task['db:drop'].invoke
    Rake::Task['db:create'].invoke
    `#{password_env}pg_restore --verbose --clean --no-acl --no-owner -h localhost -U #{database_user} -d #{database_name} #{pgdmp_filename}`
    Rake::Task['db:migrate'].invoke
  end
end
