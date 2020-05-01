module Recall
  require 'date'
  require 'net/http'

  def self.get_recall_by(recall_id: nil, recall_number: nil)
    begin
      unless recall_id.nil?
        uri = URI("https://www.saferproducts.gov/RestWebServices/Recall?RecallID=#{recall_id}&format=json")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = http.get(uri.request_uri)
        json = JSON.parse request.body
        unless json.length.zero?
          return json[0]
        else
          puts "Could not get recall for { recall_id: #{recall_id} }"
          return nil
        end
      end
      unless recall_number.nil?
        uri = URI("https://www.saferproducts.gov/RestWebServices/Recall?RecallNumber=#{recall_number}&format=json")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = http.get(uri.request_uri)
        json = JSON.parse request.body
        if json.length.zero?
          puts "Could not get recall for { recall_number: #{recall_number} }"
          return nil
        else
          return json[0]
        end
      end
    rescue Exception => e
      puts e
    end
  end

  def self.generate_sortable_date(date)
    date.match(/([a-zA-Z]+) ([\d]{1,2}), ([\d]{1,4})/) { |m|
      return '' if m.captures[0].nil? || m.captures[1].nil? || m.captures[2].nil?

      day = m.captures[1].rjust(2, '0')
      month = Date.strptime(m.captures[0], '%B').month.to_s.rjust(2, '0')
      year = m.captures[2].rjust(4, '0')
      return year + '/' + month + '/' + day 
    }
  end
end
