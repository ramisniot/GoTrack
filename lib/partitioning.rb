class Partitioning
  # The db user MUST have read permissions for the information_schema database
  # Creates a list partition with the name format of YYYY_MM
  # For a db to have a partition on a field, that field must be included in all Primary and Unique keys
  # example from readings table:  ALTER TABLE readings DROP PRIMARY KEY, ADD PRIMARY KEY(id, recorded_at);
  # then the partition should be created
  # ALTER TABLE readings
  #     PARTITION BY RANGE(TO_DAYS(recorded_at)) (
  #         PARTITION 2012_01 VALUES LESS THAN (201201),
  #         PARTITION 2012_02 VALUES LESS THAN (201202),
  #         PARTITION 2012_03 VALUES LESS THAN (201203),
  #         PARTITION 2012_04 VALUES LESS THAN (201204),
  #         PARTITION 2012_05 VALUES LESS THAN (201205),
  #         PARTITION 2012_06 VALUES LESS THAN (201206)
  #     );

  #return SQL in this method so we can use Migrations, which will know what DB to use.
  def self.create(table, field, start_date, months)
    t = Time.parse start_date
    parts = []
    months.times do |i|
      part_name = "p#{i}"
      t = t + 1.month
      parts << "PARTITION #{part_name} VALUES LESS THAN (TO_DAYS('#{t.strftime('%Y-%m-%d')}'))"
    end
    parts << "PARTITION pmax VALUES LESS THAN MAXVALUE"
    sql = "ALTER TABLE #{table} PARTITION BY RANGE(TO_DAYS(#{field})) (#{parts.join(',')})"
    sql
  end

  #intended to be called from a rake task, so the db/tablename/field/number of months will be passed in
  def self.roll(args)
    puts "Rolling partition for #{args[:database]}.#{args[:table]}"

    #TODO, update for master only
    db_config = Rails.configuration.database_configuration[Rails.env]
    db_conn = ActiveRecord::Base.establish_connection(db_config.merge("username" => "root")).connection

    sql = ActiveRecord::Base.send(:sanitize_sql_array, ["SELECT partition_name FROM information_schema.partitions WHERE table_schema = ? AND table_name = ? AND partition_name != 'pmax' ORDER BY partition_name ASC", args[:database], args[:table]])

    partitions = db_conn.select_values(sql)

    t = Time.parse(partitions.last.gsub('_', '-') + '-01')

    current = Time.now.utc.strftime("%Y_%m")

    #make sure the current month isn't dropped
    dropping = (partitions.reject { |p| p >= current })[0, args[:months].to_i]

    if dropping.size > 0

      dropping.each do |part_date|
        p_date = Time.parse(part_date.gsub('_', '-') + '-01')
        archive_sql = %[SELECT * INTO OUTFILE '/disk1/archives/archive_#{args[:database]}_#{args[:table]}_#{part_date}.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' FROM `#{args[:database]}`.`#{args[:table]}` WHERE #{args[:field]} >= '#{p_date.strftime('%Y-%m-%d')}' AND #{args[:field]} < '#{(p_date + 1.month).strftime('%Y-%m-%d')}']
        db_conn.execute(archive_sql)
      end

      drop_sql = "ALTER TABLE `#{args[:database]}`.`#{args[:table]}` DROP PARTITION #{dropping.join(', ')}"

      db_conn.execute(drop_sql)

      puts "Dropped partition(s) #{dropping[0, args[:months].to_i].join(', ')}"
    end

    new_parts = []

    #advance a month since t is the last partition before pmax
    t = t + 1.month

    args[:months].to_i.times do
      part_name = t.strftime('%Y_%m')
      t = t + 1.month
      new_parts << "PARTITION #{part_name} VALUES LESS THAN (TO_DAYS('#{t.strftime('%Y-%m-%d')}'))"
    end
    new_parts << "PARTITION pmax VALUES LESS THAN MAXVALUE"

    add_sql = "ALTER TABLE `#{args[:database]}`.`#{args[:table]}` REORGANIZE PARTITION pmax INTO (#{new_parts.join(', ')})"

    db_conn.execute(add_sql)

    puts "Added partition(s) #{new_parts.join(', ')}"
  end
end
