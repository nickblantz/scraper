module ConnectionResources
  require 'concurrent-edge'
  require 'mysql2'

  Resource = Struct.new(:id, :utilized, :connection)

  def self.configure(config, logger)
    @logger = logger
    @host = config['host']
    @port = config['port']
    @username = config['username']
    @password = config['password']
    @database_name = config['databaseName']
    @pool_size = config['poolSize']
    @resources = Concurrent::Array.new(@pool_size) { |id| Resource.new(id, false, create_connection()) }

    # log_usage_task = Concurrent::TimerTask.new(run_now: true, execution_interval: config['logUsageIntervalSecs']) do
    #   in_use = @resources.count { |r| r.utilized }
    #   free = @pool_size - in_use
    #   @logger.debug "[USAGE STATS] In Use Connections (#{in_use}) | Free Connections (#{free})"
    # end
    # log_usage_task.execute

    @logger.info 'Database connection pool configured'
    @configured = true
  end

  def self.get
    return nil unless @configured
    while true
      (0..@pool_size).each do |id|
        unless @resources[id].utilized
          @resources[id].utilized = true
          @logger.debug "Got ownership of connection #{id}"
          return @resources[id]
        end
      end
      sleep 1
    end
  end

  def self.relinquish(resource)
    @resources[resource.id].utilized = false
    @logger.debug "Relinquished ownership of connection #{resource.id}"
  end

  def self.with_connection(message, &block)
    connection_resource = get()
    begin 
      yield connection_resource.connection
    rescue Exception => e
      @logger.error "Could not #{message}"
      @logger.debug e.to_s
      @logger.trace e
    ensure
      relinquish(connection_resource)
    end
  end

  private

  def self.create_connection
    begin
      connection = Mysql2::Client.new(
        host: @host,
        port: @port,
        username: @username,
        password: @password,
        database: @database_name
      )
      @logger.info "Connection created"
      return connection
    rescue Exception => e
      @logger.error 'Could not create connection'
      @logger.debug e.to_s
      @logger.trace e
    end
  end
end
