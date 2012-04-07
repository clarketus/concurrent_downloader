module ConcurrentDownloader
  class Processor

    class << self
      def process_queue!(queue, options={}, &block)
        new.process_queue!(queue, options, &block)
      end
    end

    def process_queue!(queue, options={}, &block)
      @queue                = queue || []
      @host                 = options[:host]

      @error_limit          = options[:error_limit] || 0
      @concurrent_downloads = options[:concurrent_downloads] || 1
      @connect_timeout      = options[:connect_timeout] || 5
      @inactivity_timeout   = options[:inactivity_timeout] || 10

      @error_count          = 0
      @error_limit_passed   = false
      @response_block       = block

      EM.run do
        @concurrent_downloads.times do |downloader_id|
          recursive_download(downloader_id)
        end
      end
    end

    private

    def recursive_download(downloader_id)
      if queue_item = @queue.pop
        if queue_item.is_a?(String)
          queue_item = {:path => queue_item}
        end

        queue_item[:method] ||= "get"

        method  = queue_item[:method]
        path    = queue_item[:path]
        body    = queue_item[:body]
        head    = queue_item[:head] || {}

        head = head.merge(:downloader_id => downloader_id)

        ConcurrentDownloader.logger.info "#{downloader_id} => #{method} #{path}"

        connection = EM::HttpRequest.new @host,
          :connect_timeout    => @connect_timeout,
          :inactivity_timeout => @inactivity_timeout

        request = connection.send method,
          :path => path,
          :body => body,
          :head => head

        request.callback do |request|
          response = Response.new \
            :status   => request.response_header.status,
            :headers  => Hash[request.response_header],
            :body     => request.response

          if !@response_block.call(queue_item, response)
            handle_error DownloadError.new(queue_item, response, downloader_id)
          end
        end

        request.errback do |request|
          handle_error ConnectionError.new(queue_item, downloader_id)
        end

        [:callback, :errback].each do |meth|
          request.send(meth) do
            recursive_download(downloader_id)
          end
        end
      else
        @concurrent_downloads -= 1
        if @concurrent_downloads == 0
          EM.stop

          if @error_limit_passed
            raise @last_error
          end
        end
      end
    end

    def handle_error(error)
      ConcurrentDownloader.logger.info "#{error.downloader_id} => #{error.class}: #{error.message}"
      @last_error = error

      if @error_count < @error_limit
        @error_count += 1
        @queue << error.queue_item
      else
        @error_limit_passed = true
        @queue = []
      end
    end
  end
end
