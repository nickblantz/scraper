module DriverUtils
  require 'selenium-webdriver'

  def self.configure(logger)
    @logger = logger
    @logger.info 'Driver utilities config'
    @configured = true
  end

  def self.get_links(driver: nil, url: nil, xpath: '//a[@href]')
    if !url.nil? && url.is_a?(String)
      driver.navigate.to(url)
    else
      url = driver.current_url
    end
  
    begin
      wait = Selenium::WebDriver::Wait.new(:timeout => 10)
      links = DriverUtils::get_elements(wait: wait, driver: driver, elem_key: :xpath, elem_val: xpath)
        .map { |element| element.attribute('href') }
      return links
    rescue Selenium::WebDriver::Error => e
      @logger.error 'Could not get links'
      @logger.debug e.to_s
      @logger.trace e
      return []
    end
  end
  
  def self.get_title_and_content(driver: nil, url: nil, xpath: '//body')
    if !url.nil? && url.is_a?(String)
      driver.navigate.to(url)
    else
      url = driver.current_url
    end
  
    begin
      wait = Selenium::WebDriver::Wait.new(:timeout => 30)
      title = driver.title
      content = (DriverUtils::get_elements(wait: wait, driver: driver, elem_key: :xpath, elem_val: xpath).map { |element| element.text }).join(' ')
      return title, content
    rescue Selenium::WebDriver::Error => e
      @logger.error 'Could not get title and content'
      @logger.debug e.to_s
      @logger.trace e
      return '', ''
    end
  end

  def self.take_screenshot(driver: nil, url: nil, screenshot_file: '')
    driver.navigate.to(url) if !url.nil? && url.is_a?(String)

    begin
      driver.save_screenshot(screenshot_file)
    rescue Selenium::WebDriver::Error => e
      @logger.error 'Could not take screenshot'
      @logger.debug e.to_s
      @logger.trace e
    end
  end

  def self.get_element(driver: nil, wait: nil, elem_key: :id, elem_val: '')
    wait = Selenium::WebDriver::Wait.new(:timeout => 30) if wait.nil?
    element = wait.until {
      element = driver.find_element(elem_key, elem_val)
      element if element.displayed?
    }
    return element
  end

  def self.get_elements(driver: nil, wait: nil, elem_key: :id, elem_val: '')
    wait = Selenium::WebDriver::Wait.new(:timeout => 30) if wait.nil?
    elements = wait.until {
      elements = driver.find_elements(elem_key, elem_val)
      elements if !elements.empty? && elements[0].displayed?
    }
    return elements
  end
end