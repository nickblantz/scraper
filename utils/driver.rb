require 'concurrent-edge'
require 'selenium-webdriver'

Channel = Concurrent::Channel

class Integer
  N_BYTES = [42].pack('i').size
  N_BITS = N_BYTES * 16
  MAX = 2 ** (N_BITS - 2) - 1
  MIN = -MAX - 1
end

ENV['PATH'] = ENV['PATH'] + ';.\bin'
POOL_SIZE = 6
SCRAPE_RECURSE_MAX_DEPTH = 2
JOBS = Channel.new(buffer: :buffered, capacity: Integer::MAX)
RESULTS = Channel.new(buffer: :buffered, capacity: Integer::MAX)
GOOGLE_SEARCH_XPATH = '//div[@id="search"]//div[@id="rso"]/div[contains(@class, "g")]/div[contains(@class, "rc")]/div[contains(@class, "r")]/a'
ADBLOCK_EXTENSION_PATH = 'C:\Users\Nick Blantz\AppData\Local\Google\Chrome\User Data\Default\Extensions\gighmmpiobklfepjocnamgkkbiglidom\4.10.0_0'


def create_driver(id)
  options = Selenium::WebDriver::Chrome::Options.new()
  options.add_argument('--headless')
  options.add_argument('--disable-gpu')
  # options.add_argument('--disable-software-rasterizer')
  options.add_argument("load-extension=#{ADBLOCK_EXTENSION_PATH}")
  options.add_argument("user-data-dir=selenium_data\\user_data_#{id}")
  Selenium::WebDriver.for(:chrome, options: options)

  # Close tab code
  # wait = Selenium::WebDriver::Wait.new(:timeout => 10)
  # body = wait.until {
  #   driver.switch_to.window(driver.window_handles.last)
  #   element = driver.find_element(xpath: '//body')
  #   element if element.displayed? && driver.window_handles.length > 1
  # }
  # puts 'fart'
  # body.action.key_down(:control).send_keys('w').key_up(:control).perform
  # # body.action.send_keys(:control, 'w').perform
  # puts 'tab closed'
end

def register_recall(recall, jobs, driver) 
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

  input = wait.until {
    element = driver.find_element(:name, 'image_url')
    element if element.displayed?
  }
  input.send_keys(image_url)

  driver.action.send_keys(:enter).perform

  wait.until {
    element = driver.find_element(:id, 'search')
  }

  nil
end

def scraper_worker(id, jobs, results, driver)
  jobs.each do |job|
    puts "[#{id}] workin on #{job}"
    case job[:msg_type]
    when :REGISTER_RECALL
      register_recall(job[:recall], jobs, driver)
    when :IMAGE_SEARCH_LINKS
      google_image_search(driver: driver, image_url: job[:image_url])
      links = get_links(driver: driver, xpath: GOOGLE_SEARCH_XPATH)
      for link in links
        jobs << { msg_type: :CATEGORIZE_PAGE, page_url: link, recurse_count: 0 }
        jobs << { msg_type: :SCRAPE_PAGE, page_url: link, recurse_count: 0 }
      end
    when :CATEGORIZE_PAGE
      if job[:recurse_count] < SCRAPE_RECURSE_MAX_DEPTH
        text = get_text(driver: driver, url: job[:page_url])
        puts "[#{id}] got content, length: #{text[0].length()}"
        # for text in get_text(driver: driver, url: job[:page_url])
        # end
      end
    when :SCRAPE_PAGE
      if job[:recurse_count] < SCRAPE_RECURSE_MAX_DEPTH
        links = get_links(driver: driver, url: job[:page_url])
        puts "[#{id}] got links, length: #{links.length()}" 
        for link in get_links(driver: driver, url: job[:page_url])
          jobs << { msg_type: :CATEGORIZE_PAGE, page_url: link, recurse_count: job[:recurse_count] + 1 }
          jobs << { msg_type: :SCRAPE_PAGE, page_url: link, recurse_count: job[:recurse_count] + 1 }
        end
      end
    else
      results << { msg_type: :ERROR, content: 'Message type not supported' }
    end
  end
  driver.quit()
end

(0...POOL_SIZE).each do |id|
  Channel.go { scraper_worker(id, JOBS, RESULTS, create_driver(id)) }
end
