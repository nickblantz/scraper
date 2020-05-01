module ConnectionResources
  require 'concurrent-edge'
  require 'mysql2'
  require './lib/logger.rb'

  Resource = Struct.new(:id, :utilized, :connection)

  def self.configure(config)
    @configured = true
    @host = config['host']
    @port = config['port']
    @username = config['username']
    @password = config['password']
    @database_name = config['databaseName']
    @pool_size = config['poolSize']
    @logger = PoolLogger.new(config['logger'])
    @resources = Concurrent::Array.new(@pool_size) { |id| Resource.new(id, false, create_connection()) }

    log_usage_task = Concurrent::TimerTask.new(run_now: true, execution_interval: config['logUsageInterval']) do
      in_use = @resources.count { |r| r.utilized }
      free = @pool_size - in_use
      @logger.log "[USAGE STATS] In Use Connections (#{in_use}) | Free Connections (#{free})"
    end
    log_usage_task.execute
  end

  def self.create_connection
    @logger.log "creating database connection"
    Mysql2::Client.new(
      host: @host,
      port: @port,
      username: @username,
      password: @password,
      database: @database_name
    )
  end

  def self.get
    return nil unless @configured
    while true
      (0..@pool_size).each do |id|
        unless @resources[id].utilized
          @resources[id].utilized = true
          @logger.log "getting ownership of connection #{id}"
          return @resources[id]
        end
      end
      sleep 1
    end
  end

  def self.relinquish(resource)
    @resources[resource.id].utilized = false
    @logger.log "relinquishing ownership of connection #{resource.id}"
  end
end
