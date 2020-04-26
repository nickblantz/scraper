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

set :bind, '*'
set :port, 80

configure do
  enable :cross_origin
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
end

get '/scrape_recall/:recall_id' do |recall_id|
  ScraperWorkerPool::add_job({ msg_type: :REGISTER_RECALL, recall: get_recall(recall_id) })
  # DatabaseWorkerPool::add_job << { msg_type: :FLAG_POSSIBLE_VIOLATION, recall_id: 23, page_url: 'www.google.com', page_title: 'test' }
  "scraping recall #{recall_id}"
end
