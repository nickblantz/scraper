require 'concurrent-edge'
require 'json'
require 'selenium-webdriver'
# require './utils/analyzers.rb'



Channel = Concurrent::Channel

class Integer
  N_BYTES = [42].pack('i').size
  N_BITS = N_BYTES * 16
  MAX = 2 ** (N_BITS - 2) - 1
  MIN = -MAX - 1
end

ENV['PATH'] = ENV['PATH'] + ';.\bin'
POOL_SIZE = 4
SCRAPE_RECURSE_MAX_DEPTH = 2
JOBS = Channel.new(buffer: :buffered, capacity: Integer::MAX)
RECALLS = Hash.new()
GOOGLE_SEARCH_XPATH = '//div[@id="search"]//div[@id="rso"]/div[contains(@class, "g")]/div[contains(@class, "rc")]/div[contains(@class, "r")]/a'

def create_driver(id)
  puts "[#{id}] creating worker"

  adblock_extension_path = "#{Dir.pwd}\\selenium_data\\adblocker_extension"
  user_data_path = "#{Dir.pwd}\\selenium_data\\user_data_#{id}"

  if Dir.exist?(user_data_path)
    begin
      pref_path = "#{user_data_path}\\Default\\Preferences"
      pref_str = File.read(pref_path)
      pref_hash = JSON.parse(pref_str)
      pref_hash['profile']['exit_type'] = ''
      File.write(pref_path, JSON.generate(pref_hash))
    rescue Exception => e
      puts e
    end
  else
  end

  options = Selenium::WebDriver::Chrome::Options.new()
  options.add_argument("load-extension=#{adblock_extension_path}")
  options.add_argument("user-data-dir=#{user_data_path}")
  # options.add_argument('--headless')
  # options.add_argument('--disable-gpu')
  # options.add_argument('--disable-software-rasterizer')

  Selenium::WebDriver.for(:chrome, options: options)
end

def register_recall(recall, jobs, recalls, driver)
  recalls[recall['RecallID']] = recall
  images = recall['Images'].map { |image| image['URL'] }
  images.each do |image|
    jobs << { msg_type: :IMAGE_SEARCH_LINKS, image_url: image }
  end
end

def get_links(driver: nil, url: nil, xpath: nil)
  if !url.nil? && url.is_a?(String)
    driver.navigate.to(url)
  else
    url = driver.current_url
  end

  wait = Selenium::WebDriver::Wait.new(:timeout => 60)

  begin
    if !xpath.nil? && xpath.is_a?(String)
      output = wait.until {
        elements = driver.find_elements(xpath: xpath)
        elements.map { |element| element.attribute('href') }
      }
      output
    else
      output = wait.until {
        elements = driver.find_elements(xpath: '//a[@href]')
        elements.map { |element|
          href = element.attribute('href')
          href if (!href.include?(url) && href[0..3] == 'http')
        }
      }
      output
    end
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    []
  rescue Selenium::WebDriver::Error::TimeoutError
    []
  end
end

def get_text(driver: nil, url: nil, xpath: nil)
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
    output
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    []
  rescue Selenium::WebDriver::Error::TimeoutError
    []
  end
end

def google_image_search(driver: nil, image_url: '')
  driver.navigate.to('https://www.google.com/imghp?sbi=1')

  wait = Selenium::WebDriver::Wait.new(:timeout => 15)

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

  nil
end

def scraper_worker(id, jobs, recalls)
  driver = create_driver(id)
  jobs.each do |job|
    puts "[#{id}] workin on #{job}"
    case job[:msg_type]
    when :REGISTER_RECALL
      register_recall(job[:recall], jobs, recalls, driver)
    when :IMAGE_SEARCH_LINKS
      google_image_search(driver: driver, image_url: job[:image_url])
      links = get_links(driver: driver, xpath: GOOGLE_SEARCH_XPATH)
      puts "[#{id}] got links (length: #{links.length()})" 
      for link in links
        jobs << { msg_type: :CATEGORIZE_PAGE, page_url: link, recall_id: job[:recall]['RecallID'] }
        jobs << { msg_type: :SCRAPE_PAGE, page_url: link, recall_id: job[:recall]['RecallID'], recurse_depth: 0 }
      end
    when :CATEGORIZE_PAGE
      text = get_text(driver: driver, url: job[:page_url])
      puts "[#{id}] got content (length: #{text[0].length()})"
      # for text in get_text(driver: driver, url: job[:page_url])
      # end
    when :SCRAPE_PAGE
      if job[:recurse_depth] < SCRAPE_RECURSE_MAX_DEPTH
        links = get_links(driver: driver, url: job[:page_url])
        puts "[#{id}] got links (length: #{links.length()})" 
        for link in links
          # if LinkAnalyzer::analyze(link, job[:page_url])
            jobs << { msg_type: :CATEGORIZE_PAGE, page_url: link, recall_id: job[:recall_id] }
            jobs << { msg_type: :SCRAPE_PAGE, page_url: link, recall_id: job[:recall_id], recurse_depth: job[:recurse_depth] + 1 }
          # end
        end
      end
    else
      # Do nothing for unrecognized msg_type
    end
  end
  driver.quit()
end

(0...POOL_SIZE).each do |id|
  Channel.go { scraper_worker(id, JOBS, RECALLS) }
end
