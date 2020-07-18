class TaskUtil
  def self.get_log_and_check_running(log_name, task_name, args)
    log = Logger.new(File.join(Rails.root, 'log', "#{log_name}.log"), 'weekly')

    suffix = args.any? ? '' : args.join(' ')
    log.info "Initializing #{task_name}#{suffix}"

    running_instances = `ps aux`.split(/\n/).select { |x| x =~ /#{task_name}#{suffix}/ }

    if running_instances.size > 1
      running_instances.each do |instance|
        columns = instance.split(/\s+/)
        log.info "pid #{columns[1]} running since #{columns[8]}"
      end
      log.fatal "Instance already running, so I quit."
      exit
    elsif running_instances.size == 1
      return log
    else
      log.warn "Unexpected result when trying to find instances of this program in memory"
      exit
    end
  end
end
