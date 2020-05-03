require 'concurrent-edge'

class AppLogger
  TRACE_LEVEL = 1
  DEBUG_LEVEL = 2
  INFO_LEVEL = 4
  WARN_LEVEL = 8
  ERROR_LEVEL = 16
  FATAL_LEVEL = 32
  
  def initialize(config)
    begin
      @standard_out = config['standardOut']
      @flush_interval = config['flushInterval']
      @flush_counter = Concurrent::AtomicFixnum.new(0)
      @log_file = File.open("#{Dir.pwd}/#{config['logFile']}", 'w')
      @log_levels = parse_levels(config['logLevels'])
    rescue Exception => e
      puts e
    end
  end

  def trace(error)
    log(TRACE_LEVEL, error.backtrace.join(' '))
  end

  def debug(message)
    log(DEBUG_LEVEL, message)
  end

  def info(message)
    log(INFO_LEVEL, message)
  end

  def warn(message)
    log(WARN_LEVEL, message)
  end

  def error(message)
    log(ERROR_LEVEL, message)
  end

  def fatal(message)
    log(FATAL_LEVEL, message)
  end

  def close
    flush()
    @log_file.close
  end

  private

  def parse_levels(config)
    log_levels = 0
    for level in config
      case level
      when 'TRACE'
        log_levels |= TRACE_LEVEL
      when 'DEBUG'
        log_levels |= DEBUG_LEVEL
      when 'INFO'
        log_levels |= INFO_LEVEL
      when 'WARN'
        log_levels |= WARN_LEVEL
      when 'ERROR'
        log_levels |= ERROR_LEVEL
      when 'FATAL'
        log_levels |= FATAL_LEVEL
      else
        puts "Unrecognized log level #{level}"
      end
    end
    return log_levels
  end

  def level_to_s(level)
    case level
    when TRACE_LEVEL 
      'TRACE'
    when DEBUG_LEVEL
      'DEBUG'
    when INFO_LEVEL
      'INFO'
    when WARN_LEVEL
      'WARN'
    when ERROR_LEVEL
      'ERROR'
    when FATAL_LEVEL
      'FATAL'
    else
      'CUSTOM'
    end
  end

  def log(level, message)
    if @log_levels & level == level
      begin
        content = JSON.generate({ 
          timestamp: (Time.new).strftime("%Y-%m-%d %H:%M:%S %3N"),
          thread_id: Thread.current.object_id,
          log_level: level_to_s(level),
          message: message
        })
        puts content if @standard_out
        @log_file.puts(content)
        @flush_counter.increment(1)
      rescue Exception => e 
        puts e
      end

      if @flush_counter.value >= @flush_interval
        flush()
      end
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
end
