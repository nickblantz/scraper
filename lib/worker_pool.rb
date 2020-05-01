module WorkerPool
  require 'concurrent-edge'
  require 'csv'
  require 'selenium-webdriver'
  require './lib/analyzers/content.rb'
  require './lib/analyzers/link.rb'
  require './lib/driver_utils.rb'
  require './lib/logger.rb'
  require './lib/recall.rb'
  require './lib/resources/connection.rb'
  require './lib/resources/driver.rb'

  Job = Struct.new(:type, :payload)

  def self.configure(config)
    @configured = true
    @download_path = "#{Dir.pwd}/#{config['downloadPath']}"
    @download_path.gsub!(/\//, '\\') if (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    @pool_size = config['poolSize']
    @recurse_max_depth = config['recurseMaxDepth']
    @processed_pages = Concurrent::Hash.new
    @registered_recalls = Concurrent::Hash.new
    @logger = PoolLogger.new(config['logger'])
    @pool = Concurrent::ThreadPoolExecutor.new(
      min_threads: @pool_size,
      max_threads: @pool_size,
      max_queue: 0
    )

    clean_up_task = Concurrent::TimerTask.new(run_now: true, execution_interval: config['cleanUpInterval']) do
      @logger.log "[USAGE STATS] Queue Length (#{@pool.queue_length}) | Processed Pages Size (#{@processed_pages.length}) | Registered Recalls Size (#{@registered_recalls.length})"
    end
    clean_up_task.execute
  end

  def self.queue_job(job)
    return Concurrent::Future.execute(:executor => @pool) do
      @logger.log "starting job: #{job.type}"
      case job.type when :REFRESH_RECALLS
        refresh_recalls(job.payload)
      when :FLAG_POSSIBLE_VIOLATION
        flag_possible_violation(job.payload)
      when :REGISTER_RECALL
        register_recall(job.payload)
      when :IMAGE_SEARCH_LINKS
        image_search_links(job.payload)
      when :TEXT_SEARCH_LINKS
        text_search_links(job.payload)
      when :SCRAPE_PAGE
        scrape_page(job.payload)
      when :CATEGORIZE_PAGE
        categorize_page(job.payload)
      when :DOWNLOAD_RECALLS_CSV
        download_recall_csv(job.payload)
      else
        @logger.log "unrecognized job type"
      end
    end
  end

  def self.refresh_recalls(payload)
    recall_csv = CSV.new(File.read(payload[:recall_csv_path]))
    File.delete(payload[:recall_csv_path])
    recall_csv.each_with_index do |recall, i|
      next if i.zero?
      cpsc_recall = Recall::get_recall_by(recall_number: recall[0].gsub(/-/, ''))
      next if cpsc_recall.nil?
      recall_number = recall[0]
      recall_id = cpsc_recall['RecallID']
      high_priority = 0
      date = recall[1]
      sortable_date = Recall::generate_sortable_date(date)
      recall_heading = recall[2]
      name_of_product = recall[3]
      description = recall[4]
      hazard = recall[5]
      remedy_type = recall[6]
      units = recall[7]
      conjunction_with = recall[8]
      incidents = recall[9]
      remedy = recall[10]
      sold_at = recall[11]
      distributors = recall[12]
      manufactured_in = recall[13]
      connection_resource = ConnectionResources::get
      begin
        connection_resource.connection.query("INSERT INTO fullrecallapi (  `recall_id`,    `recall_number`,   `high_priority`,   `date`,    `sortable_date`,    `recall_heading`,    `name_of_product`,    `description`,    `hazard`,    `remedy_type`,    `units`,    `conjunction_with`,    `incidents`,    `remedy`,    `sold_at`,    `distributors`,    `manufactured_in`) 
                                                                 VALUES ('#{recall_id}', '#{recall_number}', #{high_priority}, '#{date}', '#{sortable_date}', '#{recall_heading}', '#{name_of_product}', '#{description}', '#{hazard}', '#{remedy_type}', '#{units}', '#{conjunction_with}', '#{incidents}', '#{remedy}', '#{sold_at}', '#{distributors}', '#{manufactured_in}')")
        ConnectionResources::relinquish(connection_resource)
      rescue Exception => e
        ConnectionResources::relinquish(connection_resource)
        @logger.log "Could not insert record #{e}"
      end
    end
  end

  def self.flag_possible_violation(payload)
    unless @processed_pages.has_key?(payload[:page_url])
      @processed_pages[payload[:page_url]] = true
      connection_resource = ConnectionResources::get
      begin
        connection_resource.connection.query("INSERT INTO Violation (`violation_date`, `url`, `title`, `screenshot_file`, `recall_id`, `violation_status`) VALUES ('#{Time.now.strftime("%Y-%m-%d")}', '#{payload[:page_url]}', '#{payload[:page_title]}', '#{payload[:screenshot_file]}', #{payload[:recall_id]}, 'Possible')")
        ConnectionResources::relinquish(connection_resource)
      rescue Exception => e
        ConnectionResources::relinquish(connection_resource)
        @logger.log "Could update violation #{e}" 
      end
    end
  end

  def self.register_recall(payload)
    @registered_recalls[payload[:recall]['RecallID']] = payload[:recall]
    image_urls = payload[:recall]['Images'].map { |image| image['URL'] }
    product_names = payload[:recall]['Products'].map { |product| product['Name'] }

    for image_url in image_urls
      WorkerPool::queue_job(Job.new(:IMAGE_SEARCH_LINKS, { recall_id: payload[:recall]['RecallID'], image_search: image_url }))
    end
    for product_name in product_names
      WorkerPool::queue_job(Job.new(:TEXT_SEARCH_LINKS, { recall_id: payload[:recall]['RecallID'], text_search: product_name}))
    end
  end

  def self.image_search_links(payload)
    driver_resource = DriverResources::get
    begin
      google_search_xpath = '//div[@id="search"]//div[@id="rso"]/div[contains(@class, "g")]/div[contains(@class, "rc")]/div[contains(@class, "r")]/a'
      wait = Selenium::WebDriver::Wait.new(:timeout => 30)

      driver_resource.driver.navigate.to('https://www.google.com/imghp?sbi=1')  
      search_input = wait.until {
        element = driver_resource.driver.find_element(:name, 'image_url')
        element if element.displayed?
      }
      search_input.send_keys(payload[:image_search])
      driver_resource.driver.action.send_keys(:enter).perform
      search_input = wait.until {
        element = driver_resource.driver.find_element(:name, 'q')
        element if element.displayed?
      }
      search_input.send_keys(' for sale')
      driver_resource.driver.action.send_keys(:enter).perform
      
      links = DriverUtils::get_links(driver: driver_resource.driver, xpath: google_search_xpath)
      DriverResources::relinquish(driver_resource)
      @logger.log "image got links (length: #{links.length})"
      for link in links
        WorkerPool::queue_job(Job.new(:CATEGORIZE_PAGE, { recall_id: payload[:recall_id], page_url: link }))
        WorkerPool::queue_job(Job.new(:SCRAPE_PAGE, { recall_id: payload[:recall_id], page_url: link, recurse_depth: 0 }))
      end
    rescue Exception => e
      DriverResources::relinquish(driver_resource)
      @logger.log "error while image search #{e}"
    end
  end

  def self.text_search_links(payload)
    driver_resource = DriverResources::get
    begin
      google_search_xpath = '//div[@id="search"]//div[@id="rso"]/div[contains(@class, "g")]/div[contains(@class, "rc")]/div[contains(@class, "r")]/a'
      wait = Selenium::WebDriver::Wait.new(:timeout => 30)
      
      driver_resource.driver.navigate.to('https://www.google.com/')
      search_input = wait.until {
        element = driver_resource.driver.find_element(:name, 'q')
        element if element.displayed?
      }
      search_input.send_keys(payload[:text_search])
      driver_resource.driver.action.send_keys(:enter).perform
      
      links = DriverUtils::get_links(driver: driver_resource.driver, xpath: google_search_xpath)
      DriverResources::relinquish(driver_resource)
      @logger.log "text got links (length: #{links.length})"
      for link in links
        WorkerPool::queue_job(Job.new(:CATEGORIZE_PAGE, { recall_id: payload[:recall_id], page_url: link }))
        WorkerPool::queue_job(Job.new(:SCRAPE_PAGE, { recall_id: payload[:recall_id], page_url: link, recurse_depth: 0 }))
      end
    rescue Exception => e
      DriverResources::relinquish(driver_resource)
      @logger.log "error while text search #{e}"
    end
  end

  def self.scrape_page(payload)
    if payload[:recurse_depth] < @recurse_max_depth
      driver_resource = DriverResources::get
      begin
        links = DriverUtils::get_links(driver: driver_resource.driver, url: payload[:page_url])
        @logger.log "scrape got links (length: #{links.length})"

        for link in links
          if LinkAnalyzer::analyze(link, payload[:page_url])
            WorkerPool::queue_job(Job.new(:CATEGORIZE_PAGE, { recall_id: payload[:recall_id], page_url: link }))
            WorkerPool::queue_job(Job.new(:SCRAPE_PAGE, { recall_id: payload[:recall_id], page_url: link, recurse_depth: payload[:recurse_depth] + 1 }))
          end
        end
        DriverResources::relinquish(driver_resource)
      rescue Exception => e
        DriverResources::relinquish(driver_resource)
        @logger.log "error while scraping page #{e}"
      end
    end
  end

  def self.categorize_page(payload)
    driver_resource = DriverResources::get
    begin
      title, content = DriverUtils::get_title_and_content(driver: driver_resource.driver, url: payload[:page_url])
      @logger.log "got content (length: #{content.length})"
      if ContentAnalyzer::analyze(content, @registered_recalls[payload[:recall_id]])
        screenshot_file = DriverUtils::take_screenshot(driver: driver_resource.driver, url: payload[:page_url])
        WorkerPool::queue_job(Job.new(:FLAG_POSSIBLE_VIOLATION, { recall_id: payload[:recall_id], page_url: payload[:page_url], page_title: title, screenshot_file: screenshot_file }))
      end
      DriverResources::relinquish(driver_resource)
    rescue Exception => e
      DriverResources::relinquish(driver_resource)
      @logger.log "error while categorizing page #{e}"
    end
  end

  def self.download_recall_csv(payload)
    csv_path = ((/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil) ? "#{@download_path}\\recalls_recall_listing.csv" : "#{@download_path}/recalls_recall_listing.csv"
    driver_resource = DriverResources::get
    begin
      driver_resource.driver.navigate.to('https://www.cpsc.gov/Newsroom/CPSC-RSS-Feed/Recalls-CSV')
      sleep 1 until File.file?(csv_path)
      DriverResources::relinquish(driver_resource)
      WorkerPool::queue_job(Job.new(:REFRESH_RECALLS, { recall_csv_path: csv_path }))
    rescue Exception => e
      DriverResources::relinquish(driver_resource)
      @logger.log "error while downloading recalls csv #{e}"
    end
  end
end
