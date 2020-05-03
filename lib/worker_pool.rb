module WorkerPool
  require 'concurrent-edge'
  require 'csv'
  require 'selenium-webdriver'

  Job = Struct.new(:type, :payload)

  def self.configure(config, logger)
    @logger = logger
    @download_path = "#{Dir.pwd}/#{config['downloadPath']}"
    @download_path.gsub!(/\//, '\\') if (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    @pool_size = config['poolSize']
    @max_recurse_depth = config['maxRecurseDepth']
    @processed_pages = Concurrent::Hash.new
    @registered_recalls = Concurrent::Hash.new
    @pool = Concurrent::ThreadPoolExecutor.new(
      min_threads: @pool_size,
      max_threads: @pool_size,
      max_queue: 0
    )

    clean_up_task = Concurrent::TimerTask.new(run_now: true, execution_interval: config['cleanUpInterval']) do
      @logger.debug "[USAGE STATS] Completed Jobs (#{@pool.completed_task_count}) | Queue Length (#{@pool.queue_length}) | Processed Pages Size (#{@processed_pages.length}) | Registered Recalls Size (#{@registered_recalls.length})"
    end
    clean_up_task.execute

    @logger.info 'Worker pool configured'
    @configured = true
  end

  def self.queue_job(job)
    Concurrent::Future.execute(:executor => @pool) do
      @logger.info "Starting job #{job.type}"
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
      when :SAVE_SCREENSHOT
        save_screenshot(job.payload)
      else
        @logger.error "Unrecognized Job Type #{job.type}"
      end
    end
  end

  private

  def self.refresh_recalls(payload)
    recall_csv = CSV.new(File.read(payload[:recall_csv_path]))
    File.delete(payload[:recall_csv_path])

    ConnectionResources::with_connection('create violation') do |connection|
      recall_csv.each_with_index do |recall, i|
        next if i.zero?
        cpsc_recall = RecallUtils::get_recall_by(recall_number: recall[0].gsub(/-/, ''))
        next if cpsc_recall.nil?
        ConnectionUtils::create_recall(
          connection: connection,
          recall_id: cpsc_recall['RecallID'],
          recall_number: recall[0],
          high_priority: 0,
          date: recall[1],
          sortable_date: RecallUtils::generate_sortable_date(recall[1]),
          recall_heading: recall[2],
          name_of_product: recall[3],
          description: recall[4],
          hazard: recall[5],
          remedy_type: recall[6],
          units: recall[7],
          conjunction_with: recall[8],
          incidents: recall[9],
          remedy: recall[10],
          sold_at: recall[11],
          distributors: recall[12],
          manufactured_in: recall[13]
        )
      end
      @logger.info 'Recalls refreshed'
    end
  end

  def self.flag_possible_violation(payload)
    unless @processed_pages.has_key?(payload[:page_url])
      @processed_pages[payload[:page_url]] = true

      ConnectionResources::with_connection('create violation') do |connection|
        ConnectionUtils::create_violation(
          connection: connection,
          violation_date: Time.now.strftime("%Y-%m-%d"),
          url: payload[:page_url],
          title: payload[:page_title],
          screenshot_file: payload[:screenshot_file],
          recall_id: payload[:recall_id],
          violation_status: 'Possible'
        )
        @logger.info 'Flagged possible violation'
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
    DriverResources::with_driver('complete Google image search') do |driver|
      google_search_xpath = '//div[@id="search"]//div[@id="rso"]/div[contains(@class, "g")]/div[contains(@class, "rc")]/div[contains(@class, "r")]/a'
      wait = Selenium::WebDriver::Wait.new(:timeout => 30)
      driver.navigate.to('https://www.google.com/imghp?sbi=1')
      search_input = DriverUtils::get_element(wait: wait, driver: driver, elem_key: :name, elem_val: 'image_url')
      search_input.send_keys(payload[:image_search])
      driver.action.send_keys(:enter).perform
      search_input = DriverUtils::get_element(wait: wait, driver: driver, elem_key: :name, elem_val: 'q')
      search_input.send_keys(' for sale')
      driver.action.send_keys(:enter).perform
      links = DriverUtils::get_links(driver: driver, xpath: google_search_xpath)
      for link in links
        WorkerPool::queue_job(Job.new(:CATEGORIZE_PAGE, { recall_id: payload[:recall_id], page_url: link }))
        WorkerPool::queue_job(Job.new(:SCRAPE_PAGE, { recall_id: payload[:recall_id], page_url: link, recurse_depth: 0 }))
      end
      @logger.info "Google image search got links (length: #{links.length})"
    end
  end

  def self.text_search_links(payload)
    DriverResources::with_driver('complete Google text search') do |driver|
      google_search_xpath = '//div[@id="search"]//div[@id="rso"]/div[contains(@class, "g")]/div[contains(@class, "rc")]/div[contains(@class, "r")]/a'
      wait = Selenium::WebDriver::Wait.new(:timeout => 30)
      driver.navigate.to('https://www.google.com/')
      search_input = DriverUtils::get_element(wait: wait, driver: driver, elem_key: :name, elem_val: 'q')
      search_input.send_keys(payload[:text_search])
      driver.action.send_keys(:enter).perform
      links = DriverUtils::get_links(driver: driver, xpath: google_search_xpath)
      for link in links
        WorkerPool::queue_job(Job.new(:CATEGORIZE_PAGE, { recall_id: payload[:recall_id], page_url: link }))
        WorkerPool::queue_job(Job.new(:SCRAPE_PAGE, { recall_id: payload[:recall_id], page_url: link, recurse_depth: 0 }))
      end
      @logger.info "Google text search got links (length: #{links.length})"
    end
  end

  def self.scrape_page(payload)
    if payload[:recurse_depth] < @max_recurse_depth
      DriverResources::with_driver("scrape page #{payload[:page_url]}") do |driver|
        links = DriverUtils::get_links(driver: driver, url: payload[:page_url])
        @logger.info "Page scrape got links (length: #{links.length})"
        for link in links
          if LinkAnalyzer::analyze(link, payload[:page_url])
            WorkerPool::queue_job(Job.new(:CATEGORIZE_PAGE, { recall_id: payload[:recall_id], page_url: link }))
            WorkerPool::queue_job(Job.new(:SCRAPE_PAGE, { recall_id: payload[:recall_id], page_url: link, recurse_depth: payload[:recurse_depth] + 1 }))
          end
        end
      end
    end
  end

  def self.categorize_page(payload)
    DriverResources::with_driver("categorize page #{payload[:page_url]}") do |driver|
      title, content = DriverUtils::get_title_and_content(driver: driver, url: payload[:page_url])
      if ContentAnalyzer::analyze(content, @registered_recalls[payload[:recall_id]])
        screenshot_file = "#{Dir.pwd}/public/violation_images/#{(0...12).map { (65 + rand(26)).chr }.join}.png"
        WorkerPool::queue_job(Job.new(:SAVE_SCREENSHOT, { recall_id: payload[:recall_id], page_url: payload[:page_url], screenshot_file: screenshot_file }))
        WorkerPool::queue_job(Job.new(:FLAG_POSSIBLE_VIOLATION, { recall_id: payload[:recall_id], page_url: payload[:page_url], page_title: title, screenshot_file: screenshot_file }))
      end
      @logger.info "Categorize page got content (length: #{content.length})"
    end
  end

  def self.download_recall_csv(payload)
    DriverResources::with_driver('download recall csv') do |driver|
      csv_path = ((/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil) ? "#{@download_path}\\recalls_recall_listing.csv" : "#{@download_path}/recalls_recall_listing.csv"
      driver.navigate.to('https://www.cpsc.gov/Newsroom/CPSC-RSS-Feed/Recalls-CSV')
      sleep 1 until File.file?(csv_path)
      WorkerPool::queue_job(Job.new(:REFRESH_RECALLS, { recall_csv_path: csv_path }))
      @logger.info 'Downloaded recall csv'
    end
  end

  def self.save_screenshot(payload)
    DriverResources::with_driver('take screenshot') do |driver|
      DriverUtils::take_screenshot(driver: driver, url: payload[:page_url], screenshot_file: payload[:screenshot_file])
      @logger.info 'Screenshot taken'
    end
  end
end
