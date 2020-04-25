require 'json'
require 'sinatra'
require './utils/driver.rb'
require './utils/recall.rb'

puts "starting main"
JOBS << { type: :UNDEFINED }

get '/scrape_recall/:recall_id' do |recall_id|
  JOBS << { msg_type: :REGISTER_RECALL, recall: get_recall(recall_id) } 
  "scraping recall #{recall_id}"
end

# get '/violation_search/:recall_id/google_image' do |recall_id|
#   recall = get_recall(recall_id)
#   images = recall['Images'].map { |image| image['URL'] }
#   possible_violations = []
#   driver = create_driver()

#   links = []
#   for image in images do
#     google_image_search(
#       driver: driver,
#       image_url: image
#     )
#     links = get_links(
#       driver: driver,
#       xpath: GOOGLE_SEARCH_XPATH
#     )
#   end
  
#   new_links = []
#   for link in links
#     new_links |= get_links(driver: driver, url: link)
#   end
#   output = new_links.to_s()

#   # Shutdown Driver and Return
#   driver.quit()
#   output
# end
