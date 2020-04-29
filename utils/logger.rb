require 'concurrent-edge'

class WorkerLogger
  def initialize(config)
    begin
      @flush_interval = config['flushInterval']
      @flush_counter = Concurrent::AtomicFixnum.new(0)
      @log_file = File.open("#{Dir.pwd}/#{config['logFile']}", 'w')
    rescue Exception => e
      puts e.inspect
    end
  end

  def log(id, message)
    begin
      timestamp = (Time.new).strftime("%Y-%m-%d %H:%M:%S")
      puts "#{timestamp} |#{id}| #{message}"
      @log_file.puts("#{timestamp} |#{id}| #{message}")
      @flush_counter.increment(1)
    rescue Exception => e 
      puts e
    end

    if @flush_counter.value >= @flush_interval
      self.flush()
    end
  end

  def flush()
    begin
      @flush_counter.value = 0
      @log_file.flush()
    rescue Exception => e
      puts e
    end
  end

  def close()
    @log_file.close()
  end
end