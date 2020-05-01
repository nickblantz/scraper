module DriverResources
  require 'concurrent-edge'
  require 'selenium-webdriver'
  require './lib/logger.rb'

  Resource = Struct.new(:id, :utilized, :driver)

  def self.configure(config)
    @configured = true
    @chromedriver_binary_path = "#{Dir.pwd}/#{config['chromedriverBinaryPath']}"
    @adblock_extension_path = "#{Dir.pwd}/#{config['adBlockerExtensionPath']}"
    @user_data_path = "#{Dir.pwd}/#{config['userDataPath']}"
    @download_path = "#{Dir.pwd}/#{config['downloadPath']}"
    @download_path.gsub!(/\//, '\\') if (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    @pool_size = config['poolSize']
    @logger = PoolLogger.new(config['logger'])
    @resources = Concurrent::Array.new(@pool_size) { |id| Resource.new(id, false, create_driver(id)) }

    task = Concurrent::TimerTask.new(run_now: true, execution_interval: config['usageLogInterval']) do
      in_use = @resources.count { |r| r.utilized }
      free = @pool_size - in_use
      @logger.log "[USAGE STATS] In Use Drivers (#{in_use}) | Free Drivers (#{free})"
    end
    task.execute
  end

  def self.enable_chrome_headless_downloads(id, driver, directory)
    begin
      bridge = driver.send(:bridge)
      bridge.http.call(:post, "/session/#{bridge.session_id}/chromium/send_command", {
        'cmd' => 'Page.setDownloadBehavior',
        'params' => {
          'behavior' => 'allow',
          'downloadPath' => directory,
        }
      })
    rescue Exception => e
      @logger.log "Error sending send_command http to chrome"
    end
  end

  def self.create_driver(id)
    @logger.log "creating webdriver"  
    user_data_dir = "#{@user_data_path}/user_data_#{id}"
    options = Selenium::WebDriver::Chrome::Options.new
    
    # Logging Settings
    options.add_argument('--silent')
    options.add_argument('--log-level=3')

    # Headless Settings
    options.add_argument('--headless')
    options.add_argument('--disable-gpu')
    options.add_argument('--no-sandbox')
    options.add_argument("--disable-software-rasterizer")

    # Miscellaneous Settings
    options.add_argument("--start-maximized")
    options.add_argument('--disable-web-security')
    options.add_argument("--test-type")

    # Directory Settings
    Selenium::WebDriver::Chrome::Service.driver_path = @chromedriver_binary_path
    options.add_argument("load-extension=#{@adblock_extension_path}")
    options.add_argument("user-data-dir=#{user_data_dir}")
    options.add_preference(
      :download, 
      directory_upgrade: true,
      prompt_for_download: false,
      default_directory: @download_path
    )

    # Previous Exit Settings
    begin
      pref_path = "#{user_data_dir}/Default/Preferences"
      pref_str = File.read(pref_path)
      pref_hash = JSON.parse(pref_str)
      pref_hash['profile']['exit_type'] = ''
      File.write(pref_path, JSON.generate(pref_hash))
    rescue Exception => e
      @logger.log "could not edit preferences #{e}"
    end
    
    begin
      driver = Selenium::WebDriver.for(:chrome, options: options)
      enable_chrome_headless_downloads(id, driver, @download_path)
      return driver
    rescue Exception => e
      @logger.log "could not create driver #{e}"
      return nil
    end
  end

  def self.get
    return nil unless @configured
    while true
      (0..@pool_size).each do |id|
        unless @resources[id].utilized
          @resources[id].utilized = true
          @logger.log "getting ownership of driver #{id}"
          return @resources[id]
        end
      end
      sleep 1
    end
  end

  def self.relinquish(resource)
    @resources[resource.id].utilized = false
    @logger.log "relinquishing ownership of driver #{resource.id}"
  end
end
