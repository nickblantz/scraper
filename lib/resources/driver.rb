module DriverResources
  require 'concurrent-edge'
  require 'selenium-webdriver'

  Resource = Struct.new(:id, :utilized, :driver)

  def self.configure(config, logger)
    @logger = logger
    @chromedriver_binary_path = "#{Dir.pwd}/#{config['chromedriverBinaryPath']}"
    @adblock_extension_path = "#{Dir.pwd}/#{config['adBlockerExtensionPath']}"
    @user_data_path = "#{Dir.pwd}/#{config['userDataPath']}"
    @download_path = "#{Dir.pwd}/#{config['downloadPath']}"
    @download_path.gsub!(/\//, '\\') if (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    @pool_size = config['poolSize']
    @resources = Concurrent::Array.new(@pool_size) { |id| Resource.new(id, false, create_driver(id)) }

    # task = Concurrent::TimerTask.new(run_now: true, execution_interval: config['logUsageIntervalSecs']) do
    #   in_use = @resources.count { |r| r.utilized }
    #   free = @pool_size - in_use
    #   @logger.debug "[USAGE STATS] In Use Drivers (#{in_use}) | Free Drivers (#{free})"
    # end
    # task.execute

    @logger.info 'Selenium Driver pool configured'
    @logger.debug @resources.inspect
    @configured = true
  end

  def self.get
    return nil unless @configured
    while true
      @resources.each do |resource|
        unless resource.utilized
          resource.utilized = true
          @logger.debug "Got ownership of driver #{resource.id}"
          return resource
        end
      end
      sleep 1
    end
  end

  def self.relinquish(resource)
    @resources[resource.id].utilized = false
    @logger.debug "Relinquished ownership of driver #{resource.id}"
  end

  def self.with_driver(message, &block)
    driver_resource = get()
    begin 
      yield driver_resource.driver
    rescue Exception => e
      @logger.error "Could not #{message}"
      @logger.debug e.to_s
      @logger.trace e
    ensure
      relinquish(driver_resource)
    end
  end

  private

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
      @logger.error 'Could not enable downloads in headless chrome'
      @logger.debug e.to_s
      @logger.trace e
    end
  end

  def self.create_driver(id)
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
      @logger.error 'Could not edit preferences'
      @logger.debug e.to_s
      @logger.trace e
    end
    
    begin
      driver = Selenium::WebDriver.for(:chrome, options: options)
      enable_chrome_headless_downloads(id, driver, @download_path)
      @logger.info "Driver created"
      return driver
    rescue Exception => e
      @logger.error 'Could not create driver'
      @logger.debug e.to_s
      @logger.trace e
      return nil
    end
  end
end
