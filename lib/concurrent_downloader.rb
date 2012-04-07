require 'logger'

require 'eventmachine'
require 'em-http-request'

require 'concurrent_downloader/version'
require 'concurrent_downloader/response'
require 'concurrent_downloader/processor'

module ConcurrentDownloader

  class << self
    def process_queue!(queue, options={}, &block)
      Processor.process_queue!(queue, options, &block)
    end

    def logger
      @logger ||= Logger.new('/dev/null')
    end

    def logger=(logger)
      @logger = logger
    end
  end

  class ConnectionError < StandardError
    attr_reader \
      :queue_item,
      :downloader_id

    def initialize(queue_item, downloader_id)
      @queue_item = queue_item
      @downloader_id = downloader_id
    end

    def message
      "There was a connection error: #{@queue_item[:method].upcase} #{@queue_item[:path]}"
    end
  end

  class DownloadError < StandardError
    attr_reader \
      :queue_item,
      :response,
      :downloader_id

    def initialize(queue_item, response, downloader_id)
      @queue_item = queue_item
      @response = response
      @downloader_id = downloader_id
    end

    def message
      "There was a download error: #{@queue_item[:method].upcase} #{@queue_item[:path]}: #{@response.status}"
    end
  end
end

