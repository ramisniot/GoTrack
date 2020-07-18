namespace :gotrack do
  desc 'Delete movement alerts after 1 month'
  task remove_old_movement_alerts: :environment do
    logger.info('Starting to delete old movement alerts...')

    sql = %{
      DELETE FROM movement_alerts
      WHERE updated_at < NOW() - INTERVAL '1 MONTH'
    }

    result = ActiveRecord::Base.connection.execute(sql)
    logger.info("#{result.cmd_tuples} movement alerts deleted")
  end

  desc 'Delete already-delivered scheduled reports that are more than 1 week old'
  task remove_old_scheduled_reports: :environment do
    logger.info('Starting to delete old scheduled reports...')

    sql = %{
      DELETE FROM background_reports
      WHERE
      completed = '1' AND type = 'ScheduledReport' AND scheduled_for < NOW() - INTERVAL '7 DAY'
    }

    result = ActiveRecord::Base.connection.execute(sql)
    logger.info("#{result.cmd_tuples} scheduled reports deleted")
  end

  def logger
    @logger ||= Logger.new(STDOUT)
  end
end
