module DriverUtils
  require 'selenium-webdriver'

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
  
  def self.get_title_and_content(driver: nil, url: nil, xpath: nil)
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
        elements.map { |element| element.text }
      }
      return driver.title, output.join(' ')
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      return "", ""
    rescue Selenium::WebDriver::Error::TimeoutError
      return "", ""
    end
  end

  def self.take_screenshot(driver: nil, url: nil)
    if !url.nil? && url.is_a?(String)
      driver.navigate.to(url)
    else
      url = driver.current_url
    end

    image_name = (0...12).map { (65 + rand(26)).chr }.join + '.png'
    file = "#{Dir.pwd}/public/violation_images/#{image_name}"

    begin
      driver.save_screenshot(file)
      return image_name
    rescue Exception => e
      return nil
    end
  end
end
