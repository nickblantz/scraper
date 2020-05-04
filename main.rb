require 'concurrent-edge'
require 'json'
require 'sinatra/base'
require 'sinatra/cross_origin'
require './lib/analyzers/content.rb'
require './lib/analyzers/link.rb'
require './lib/logger.rb'
require './lib/resources/connection.rb'
require './lib/resources/driver.rb'
require './lib/utils/connection.rb'
require './lib/utils/driver.rb'
require './lib/utils/recall.rb'
require './lib/worker_pool.rb'

module Sinatra
  class ScraperApp < Sinatra::Base
    configure do
      config = JSON.parse(File.read('config.json')).freeze
      logger = AppLogger.new(config['logger'])

      ContentAnalyzer::configure(config['contentAnalyzer'], logger)
      LinkAnalyzer::configure(config['linkAnalyzer'], logger)
      ConnectionResources::configure(config['connectionResources'], logger)
      DriverResources::configure(config['driverResources'], logger)
      ConnectionUtils::configure(logger)
      DriverUtils::configure(logger)
      RecallUtils::configure(logger)
      WorkerPool::configure(config['workerPool'], logger)

      recall_refresh_task = Concurrent::TimerTask.new(run_now: true, execution_interval: config['server']['recallRefreshIntervalSecs']) do
        WorkerPool::queue_job(WorkerPool::Job.new(:DOWNLOAD_RECALLS_CSV, {}))
      end
      recall_refresh_task.execute

      enable :cross_origin
      set :port, config['server']['port']
      if config['server']['production']
        set :environment, :production
        set :bind, '*'
      end
    end

    before do
      response.headers['Access-Control-Allow-Origin'] = '*'
    end

    post '/scrape_recall/:recall_id' do |recall_id|
      WorkerPool::queue_job(WorkerPool::Job.new(:REGISTER_RECALL, { recall: RecallUtils::get_recall_by(recall_id: recall_id) }))
      return "scraping recall #{recall_id}"
    end

    post '/refresh_recalls' do
      WorkerPool::queue_job(WorkerPool::Job.new(:DOWNLOAD_RECALLS_CSV, {}))
      return 'refreshing recalls'
    end

    run! if __FILE__ == $0
  end
end
