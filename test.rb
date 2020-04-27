require 'net/http'
# require 'open-uri'

# Net::HTTP.start("www.cpsc.gov") do |http|
#   resp = http.get("/Newsroom/CPSC-RSS-Feed/Recalls-CSV")
#   open("recalls.csv", "wb") do |file|
#     file.write(resp.body)
#   end
# end

# response = Net::HTTP.get_response(URI.parse("https://www.cpsc.gov/Newsroom/CPSC-RSS-Feed/Recalls-CSV"))
# response.each_key do |key|
#   puts "response[#{key}] = #{response[key]}"
# end

File.write 'recalls.csv', open('https://www.cpsc.gov/Newsroom/CPSC-RSS-Feed/Recalls-CSV?').read

