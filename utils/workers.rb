require 'concurrent-edge'
require 'json'
require 'csv'
require 'selenium-webdriver'
require 'mysql2'
require 'net/http'
require './utils/analyzers.rb'
require './utils/recall.rb'

class Integer
  N_BYTES = [42].pack('i').size
  N_BITS = N_BYTES * 16
  MAX = 2 ** (N_BITS - 2) - 1
  MIN = -MAX - 1
end

def write_to_log(file, message)
  time = Time.new
  timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
  puts "#{timestamp} | #{message}"
  file.puts("#{timestamp} | #{message}")
end

module DatabaseWorkerPool
  def self.configure(config)
    @host = config['host']
    @port = config['port']
    @username = config['username']
    @password = config['password']
    @database_name = config['databaseName']
    @recall_table_name = config['recallTableName']
    @violation_table_name = config['violationTableName']
    @worker_pool_size = config['workerPoolSize']
    @jobs = Concurrent::Channel.new(buffer: :buffered, capacity: Integer::MAX)
    @processed_pages = Hash.new()
    
    (0...@worker_pool_size).each do |id|
      Concurrent::Channel.go { DatabaseWorkerPool::worker(id, @jobs) }
    end
  end

  def self.add_job(job)
    @jobs << job
  end

  def self.create_connection(id)
    Mysql2::Client.new(
      host: @host,
      port: @port,
      username: @username,
      password: @password,
      database: @database_name
    )
  end
  
  def self.worker(id, jobs)
    log_file = File.open("logs/database_worker_#{id}.log", 'w')
    write_to_log(log_file, "creating database worker")
    conn = create_connection(id)
    jobs.each do |job|
      write_to_log(log_file, "starting job: #{job}")
      case job[:msg_type]
      when :FLAG_POSSIBLE_VIOLATION
        unless @processed_pages.has_key?(job[:page_url])
          @processed_pages[job[:page_url]] = true
          begin
            results = conn.query("INSERT INTO #{@violation_table_name} (`violation_date`, `url`, `title`, `recall_id`, `violation_status`) VALUES ('#{Time.now.strftime("%Y-%m-%d")}', '#{job[:page_title]}', '#{job[:page_url]}', #{job[:recall_id]}, 'Possible')")
          rescue Exception => e
            write_to_log(log_file, "Could not insert record #{e}")
          end
        end
      when :REFRESH_RECALLS
        csv = CSV.new(File.read(job[:recall_csv_file_path]))
        csv.each_with_index do |recall, i|
          next if i == 0
          recall_number = recall[0].gsub(/-/, '')
          recall_id = get_recall_by(recall_number: recall_number)['RecallID']
          high_priority = false
          date = recall[1]
          sortable_date = generate_sortable_date(date)
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
          begin
            # puts "INSERT INTO #{@recall_table_name} (`recall_id`, `recall_number`, `high_priority`, `date`, `sortable_date`, `recall_heading`, `name_of_product`, `description`, `hazard`, `remedy_type`, `units`, `conjunction_with`, `incidents`, `remedy`, `sold_at`, `distributors`, `manufactured_in`) VALUES ('#{recall_id}', '#{high_priority}', '#{date}', '#{sortable_date}', '#{recall_heading}', '#{name_of_product}', '#{description}', '#{hazard}', '#{remedy_type}', '#{units}', '#{conjunction_with}', '#{incidents}', '#{remedy}', '#{sold_at}', '#{distributors}', '#{manufactured_in}')"
            results = conn.query("INSERT INTO #{@recall_table_name} (`recall_id`, `recall_number`, `high_priority`, `date`, `sortable_date`, `recall_heading`, `name_of_product`, `description`, `hazard`, `remedy_type`, `units`, `conjunction_with`, `incidents`, `remedy`, `sold_at`, `distributors`, `manufactured_in`) 
            VALUES ('#{recall_id}', #{recall_number}, '#{high_priority}', '#{date}', '#{sortable_date}', '#{recall_heading}', '#{name_of_product}', '#{description}', '#{hazard}', '#{remedy_type}', '#{units}', '#{conjunction_with}', '#{incidents}', '#{remedy}', '#{sold_at}', '#{distributors}', '#{manufactured_in}')")
          rescue Exception => e
            write_to_log(log_file, "Could not insert record #{e}")
          end
        end
      else
      end
    end
    write_to_log(log_file, "shutting down worker")
    conn.close()
    log_file.close()
  end
end

module ScraperWorkerPool
  def self.configure(config)
    @chromedriver_binary_path = "#{Dir.pwd}/#{config['chromedriverBinaryPath']}"
    @adblock_extension_path = "#{Dir.pwd}/#{config['adBlockerExtensionPath']}"
    @user_data_path = "#{Dir.pwd}/#{config['userDataPath']}"
    @download_path = "#{Dir.pwd}/#{config['downloadPath']}" # .gsub!(/\//, '\\')
    @recurse_max_depth = config['recurseMaxDepth']
    @worker_pool_size = config['workerPoolSize']
    @jobs = Concurrent::Channel.new(buffer: :buffered, capacity: Integer::MAX)
    @recalls = Hash.new
    
    (0...@worker_pool_size).each do |id|
      Concurrent::Channel.go { ScraperWorkerPool::worker(id, @jobs, @recalls) }
    end
  end

  def self.add_job(job)
    @jobs << job
  end

  def self.enable_chrome_headless_downloads(driver, directory)
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
      puts e
    end
  end

  def self.create_driver(id, log_file)
    user_data_dir = "#{@user_data_path}/user_data_#{id}"
  
    if Dir.exist?(user_data_dir)
      begin
        pref_path = "#{user_data_dir}/Default/Preferences"
        pref_str = File.read(pref_path)
        pref_hash = JSON.parse(pref_str)
        pref_hash['profile']['exit_type'] = ''
        File.write(pref_path, JSON.generate(pref_hash))
      rescue Exception => e
        write_to_log(log_file, "could not edit preferences #{e}")
      end
    else
    end
    
    begin
      options = Selenium::WebDriver::Chrome::Options.new()
      options.add_argument('--silent')
      options.add_argument('--log-level=3')
      options.add_argument('--headless')
      options.add_argument('--disable-gpu')
      options.add_argument('--no-sandbox')
      options.add_argument("--disable-software-rasterizer")
      options.add_argument('--incognito')
      options.add_argument('--disable-web-security')
      options.add_argument("--test-type")
      options.add_argument("load-extension=#{@adblock_extension_path}")
      options.add_argument("user-data-dir=#{user_data_dir}")
      options.add_preference(
        :download, 
        directory_upgrade: true,
        prompt_for_download: false,
        default_directory: @download_path
      )
      driver = Selenium::WebDriver.for(:chrome, options: options, driver_path: @chromedriver_binary_path)
      enable_chrome_headless_downloads(driver, @download_path)
      return driver
    rescue Exception => e
      write_to_log(log_file, "could not create driver #{e}")
      return nil
    end
  end
  
  def self.register_recall(recall, jobs, recalls, driver)
    recalls[recall['RecallID']] = recall
    
    images = recall['Images'].map { |image| image['URL'] }
    images.each do |image|
      jobs << { msg_type: :IMAGE_SEARCH_LINKS, recall_id: recall['RecallID'], image_url: image }
      
    end
  
    product_names = recall['Products'].map { |product| product['Name'] }
    for product_name in product_names
      jobs << { msg_type: :PRODUCT_NAME_SEARCH_LINKS, recall_id: recall['RecallID'], product_name: product_name}
    end
  end
  
  def self.get_links(driver: nil, url: nil, xpath: nil)
    if !url.nil? && url.is_a?(String)
      driver.navigate.to(url)
    else
      url = driver.current_url
    end
  
    if xpath.nil? || !xpath.is_a?(String)
      xpath = '//a[@href]'
    end
  
    wait = Selenium::WebDriver::Wait.new(:timeout => 60)
  
    begin
      output = wait.until {
        elements = driver.find_elements(xpath: xpath)
        elements.map { |element| element.attribute('href') }
      }
      return output
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      return []
    rescue Selenium::WebDriver::Error::TimeoutError
      return []
    end
  end
  
  def self.get_text(driver: nil, url: nil, xpath: nil)
    if !url.nil? && url.is_a?(String)
      driver.navigate.to(url)
    else
      url = driver.current_url
    end
  
    if xpath.nil? || !xpath.is_a?(String)
      xpath = '//body'
    end
  
    wait = Selenium::WebDriver::Wait.new(:timeout => 60)
  
    begin
      output = wait.until {
        elements = driver.find_elements(xpath: xpath)
        elements.map { |element| element.text() }
      }
      return output.join(' ')
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      return ""
    rescue Selenium::WebDriver::Error::TimeoutError
      return ""
    end
  end
  
  def self.google_image_search(driver: nil, image_url: '')
    google_search_xpath = '//div[@id="search"]//div[@id="rso"]/div[contains(@class, "g")]/div[contains(@class, "rc")]/div[contains(@class, "r")]/a'
    wait = Selenium::WebDriver::Wait.new(:timeout => 30)
  
    driver.navigate.to('https://www.google.com/imghp?sbi=1')  
    search_input = wait.until {
      element = driver.find_element(:name, 'image_url')
      element if element.displayed?
    }
    search_input.send_keys(image_url)
    driver.action.send_keys(:enter).perform
    search_input = wait.until {
      element = driver.find_element(:name, 'q')
      element if element.displayed?
    }
    search_input.send_keys(' for sale')
    driver.action.send_keys(:enter).perform
  
    return nil
  end
  
  def self.google_text_search(driver: nil, search_text: '')
    google_search_xpath = '//div[@id="search"]//div[@id="rso"]/div[contains(@class, "g")]/div[contains(@class, "rc")]/div[contains(@class, "r")]/a'
    wait = Selenium::WebDriver::Wait.new(:timeout => 30)

    driver.navigate.to('https://www.google.com/')
    search_input = wait.until {
      element = driver.find_element(:name, 'q')
      element if element.displayed?
    }
    search_input.send_keys(search_text)
    driver.action.send_keys(:enter).perform
  
    return nil
  end
  
  def self.worker(id, jobs, recalls)
    log_file = File.open("logs/scraper_worker_#{id}.log", 'w')
  
    write_to_log(log_file, "creating scraper worker")
    driver = create_driver(id, log_file)
    jobs.each do |job|
      write_to_log(log_file, "starting job: #{job}")
      case job[:msg_type]
      when :REGISTER_RECALL
        register_recall(job[:recall], jobs, recalls, driver)
      when :IMAGE_SEARCH_LINKS
        google_image_search(driver: driver, image_url: job[:image_url])
        links = get_links(driver: driver, xpath: '//div[@id="search"]//div[@id="rso"]/div[contains(@class, "g")]/div[contains(@class, "rc")]/div[contains(@class, "r")]/a')
        write_to_log(log_file, "got links (length: #{links.length()})")
        for link in links
          jobs << { msg_type: :CATEGORIZE_PAGE, recall_id: job[:recall_id], page_url: link }
          jobs << { msg_type: :SCRAPE_PAGE, recall_id: job[:recall_id], page_url: link, recurse_depth: 0 }
        end
      when :PRODUCT_NAME_SEARCH_LINKS
        google_text_search(driver: driver, search_text: "#{job[:product_name]} for sale")
        links = get_links(driver: driver, xpath: '//div[@id="search"]//div[@id="rso"]/div[contains(@class, "g")]/div[contains(@class, "rc")]/div[contains(@class, "r")]/a')
        write_to_log(log_file, "got links (length: #{links.length()})")
        for link in links
          jobs << { msg_type: :CATEGORIZE_PAGE, recall_id: job[:recall_id], page_url: link }
          jobs << { msg_type: :SCRAPE_PAGE, recall_id: job[:recall_id], page_url: link, recurse_depth: 0 }
        end
      when :CATEGORIZE_PAGE
        text = get_text(driver: driver, url: job[:page_url])
        write_to_log(log_file, "got content (length: #{text.length()})")
        if ContentAnalyzer::analyze(text, recalls[job[:recall_id]])
          DatabaseWorkerPool::add_job({ msg_type: :FLAG_POSSIBLE_VIOLATION, recall_id: job[:recall_id], page_url: job[:page_url], page_title: driver.title })
        end
      when :SCRAPE_PAGE
        if job[:recurse_depth] < @recurse_max_depth
          links = get_links(driver: driver, url: job[:page_url])
          write_to_log(log_file, "got links (length: #{links.length()})")
          for link in links
            if LinkAnalyzer::analyze(link, job[:page_url])
              jobs << { msg_type: :CATEGORIZE_PAGE, recall_id: job[:recall_id], page_url: link }
              jobs << { msg_type: :SCRAPE_PAGE, recall_id: job[:recall_id], page_url: link, recurse_depth: job[:recurse_depth] + 1 }
            end
          end
        end
      when :DOWNLOAD_RECALLS_CSV
        begin
          # driver.navigate.to('https://www.cpsc.gov/Newsroom/CPSC-RSS-Feed/Recalls-CSV')
        rescue Exception => e
          puts e
        end
        DatabaseWorkerPool::add_job({ msg_type: :REFRESH_RECALLS, recall_csv_file_path: "#{@download_path}\\recalls_recall_listing.csv" })
      else
        # Do nothing for unrecognized msg_type
      end
    end
  
    write_to_log(log_file, "shutting down worker")
    driver.quit()
    log_file.close()
  end
end
