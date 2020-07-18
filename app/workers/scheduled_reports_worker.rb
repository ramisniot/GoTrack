class ScheduledReportsWorker
  include Sidekiq::Worker

  def perform(payload)
    logger.info "#{Time.now.to_s(:db)} - INCOMING REPORT MESSAGE - #{payload}"
    begin
      scheduled_report = ScheduledReport.not_completed.find_by_id(payload['id'])
      scheduled_report.try(:process, logger)
    rescue => exc
      logger.info exc.message
    end
  end
end
