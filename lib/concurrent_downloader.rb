require 'logger'

require 'eventmachine'
require 'em-http-request'

require 'concurrent_downloader/version'
require 'concurrent_downloader/processor'

module ConcurrentDownloader

  class << self
    def process_queue!(*args, &block)
      Processor.new.process_queue!(*args, &block)
    end

    def logger
      @logger ||= Logger.new('/dev/null')
    end

    def logger=(logger)
      @logger = logger
    end
  end

  class DownloadError < StandardError; end
end

