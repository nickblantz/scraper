require 'json'
require 'sinatra'
require 'sinatra/cross_origin'
require './utils/analyzers.rb'
require './utils/recall.rb'
require './utils/workers.rb'

config = JSON.parse(File.read('config.json'))
DatabaseWorkerPool::configure(config['databaseWorkerPool'])
ScraperWorkerPool::configure(config['scraperWorkerPool'])
ContentAnalyzer::configure(config['contentAnalyzer'])
LinkAnalyzer::configure(config['linkAnalyzer'])

# set :bind, '*'
# set :port, 80

configure do
  enable :cross_origin
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
end

post '/scrape_recall/:recall_id' do |recall_id|
  ScraperWorkerPool::add_job({ msg_type: :REGISTER_RECALL, recall: get_recall_by_id(recall_id) })
  return "scraping recall #{recall_id}"
end

get '/refresh_recalls' do
  ScraperWorkerPool::add_job({ msg_type: :DOWNLOAD_RECALLS_CSV })
  # DatabaseWorkerPool::add_job({ msg_type: :REFRESH_RECALLS })
  return 'refreshing regalls'
end

