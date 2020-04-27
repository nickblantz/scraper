require 'net/http'

def get_recall_by_id(recall_id)
  uri = URI("https://www.saferproducts.gov/RestWebServices/Recall?RecallID=#{recall_id}&format=json")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = http.get(uri.request_uri)
  (JSON.parse request.body)[0]
end

def get_recall_by_number(recall_number)
  uri = URI("https://www.saferproducts.gov/RestWebServices/Recall?RecallNumber=#{recall_number}&format=json")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = http.get(uri.request_uri)
  (JSON.parse request.body)[0]
end
