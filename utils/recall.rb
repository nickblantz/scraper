require 'net/http'

def get_recall(recall_id)
  uri = URI("https://www.saferproducts.gov/RestWebServices/Recall?RecallID=#{recall_id}&format=json")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = http.get(uri.request_uri)
  (JSON.parse request.body)[0]
end
