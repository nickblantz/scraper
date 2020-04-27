require 'date'
require 'net/http'

def get_recall_by(recall_id: nil, recall_number: nil)
  unless recall_id.nil?
    uri = URI("https://www.saferproducts.gov/RestWebServices/Recall?RecallID=#{recall_id}&format=json")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = http.get(uri.request_uri)
    return (JSON.parse request.body)[0]
  end
  unless recall_number.nil?
    uri = URI("https://www.saferproducts.gov/RestWebServices/Recall?RecallNumber=#{recall_number}&format=json")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = http.get(uri.request_uri)
    return (JSON.parse request.body)[0]
  end
end

def generate_sortable_date(date)
  date.match(/([a-zA-Z]+) ([\d]{1,2}), ([\d]{1,4})/) { |m|
    return '' if m.captures[0].nil? || m.captures[1].nil? || m.captures[2].nil?

    day = m.captures[1].rjust(2, '0')
    month = Date.strptime(m.captures[0], '%B').month.to_s.rjust(2, '0')
    year = m.captures[2].rjust(4, '0')
    return year + '/' + month + '/' + day 
  }
end
