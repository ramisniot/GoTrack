namespace :gotrack do
  desc 'Send maintenance notifications'
  task send_maintenance_notifications: :environment do
    Notifier.send_maintenance_notifications(Logger.new(STDOUT))
  end
end
