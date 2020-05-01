require 'json'
require 'sinatra/base'
require 'sinatra/cross_origin'
require './lib/analyzers/content.rb'
require './lib/analyzers/link.rb'
require './lib/resources/connection.rb'
require './lib/resources/driver.rb'
require './lib/recall.rb'
require './lib/worker_pool.rb'

module Sinatra
  class ScraperApp < Sinatra::Base
    configure do
      config = JSON.parse(File.read('config.json'))
      ConnectionResources::configure(config['connectionResources'])
      DriverResources::configure(config['driverResources'])
      WorkerPool::configure(config['workerPool'])
      ContentAnalyzer::configure(config['contentAnalyzer'])
      LinkAnalyzer::configure(config['linkAnalyzer'])

      enable :cross_origin
      set :bind, '*' if config['server']['production']
      set :port, config['server']['port']
    end

    before do
      response.headers['Access-Control-Allow-Origin'] = '*'
    end

    get '/scrape_recall/:recall_id' do |recall_id|
      WorkerPool::queue_job(WorkerPool::Job.new(:REGISTER_RECALL, { recall: Recall::get_recall_by(recall_id: recall_id) }))
      return "scraping recall #{recall_id}"
    end

    get '/refresh_recalls' do
      WorkerPool::queue_job(WorkerPool::Job.new(:DOWNLOAD_RECALLS_CSV, {}))
      return 'refreshing recalls'
    end

    run! if __FILE__ == $0
  end
end
