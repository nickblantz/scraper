module RecallUtils
  require 'date'
  require 'net/http'

  def self.configure(logger)
    @logger = logger
    @logger.info 'Recall utilities config'
    @configured = true
  end

  def self.get_recall_by(recall_id: nil, recall_number: nil)
    unless recall_id.nil?
      json = get_recalls_json(query: "RecallID=#{recall_id}")
      unless json.length.zero?
        return json[0]
      else
        @logger.warn "No recalls found for recall_id #{recall_id}"
        return nil
      end
    end
    unless recall_number.nil?
      json = get_recalls_json(query: "RecallNumber=#{recall_number}")
      unless json.length.zero?
        return json[0]
      else
        @logger.warn "No recalls found for recall_number #{recall_number} }"
        return nil
      end
    end
  end

  def self.generate_sortable_date(date)
    date.match(/([a-zA-Z]+) ([\d]{1,2}), ([\d]{1,4})/) { |m|
      if m.captures[0].nil? || m.captures[1].nil? || m.captures[2].nil?
        @logger.warn "Could not match date #{date}"
        return '' 
      end

      day = m.captures[1].rjust(2, '0')
      month = Date.strptime(m.captures[0], '%B').month.to_s.rjust(2, '0')
      year = m.captures[2].rjust(4, '0')
      return year + '/' + month + '/' + day 
    }
  end

  private

  def self.get_recalls_json(query: '')
    begin
      uri = URI("https://www.saferproducts.gov/RestWebServices/Recall?#{query}&format=json")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = http.get(uri.request_uri)
      return JSON.parse request.body
    rescue Exception => e
      @logger.error 'Could not reach recalls endpoint'
      @logger.debug e.to_s
      @logger.trace e
    end
  end
end
