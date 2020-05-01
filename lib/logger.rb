require 'concurrent-edge'

class PoolLogger
  def initialize(config)
    begin
      @standard_out = config['standardOut']
      @flush_interval = config['flushInterval']
      @flush_counter = Concurrent::AtomicFixnum.new(0)
      @log_file = File.open("#{Dir.pwd}/#{config['logFile']}", 'w')
    rescue Exception => e
      puts e
    end
  end

  def log(message)
    begin
      timestamp = (Time.new).strftime("%Y-%m-%d %H:%M:%S")
      thread_id = Thread.current.object_id
      puts "[#{timestamp}] [#{thread_id}] #{message}" if @standard_out
      @log_file.puts("[#{timestamp}] [#{thread_id}] #{message}")
      @flush_counter.increment(1)
    rescue Exception => e 
      puts e
    end

    if @flush_counter.value >= @flush_interval
      self.flush
    end
  end

  def flush
    begin
      @flush_counter.value = 0
      @log_file.flush
    rescue Exception => e
      puts e
    end
  end

  def close
    self.flush
    @log_file.close
  end
end
