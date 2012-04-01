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
        @concurrent_downloads.times do
          recursive_download
        end
      end
    end

    def recursive_download
      if queue_item = @queue.pop
        method  = queue_item[:method] || "get"
        path    = queue_item[:path]
        body    = queue_item[:body]
        head    = queue_item[:head] || {}

        ConcurrentDownloader.logger.info "#{method} #{path}"

        connection = EM::HttpRequest.new @host,
          :connect_timeout    => @connect_timeout,
          :inactivity_timeout => @inactivity_timeout

        request = connection.send method,
          :path => path,
          :body => body,
          :head => head

        request.callback do |request|
          if !@response_block.call(queue_item, request)
            handle_error(request, queue_item)
          end
        end

        request.errback do |request|
          handle_error(request, queue_item)
        end

        [:callback, :errback].each do |meth|
          request.send(meth) do
            recursive_download
          end
        end
      else
        @concurrent_downloads -= 1
        if @concurrent_downloads == 0
          EM.stop

          if @error_limit_passed
            raise DownloadError.new("There was a download error")
          end
        end
      end
    end

    def handle_error(request, current_download)
      ConcurrentDownloader.logger.info "Error received: #{request.response_header.status} #{request.inspect}"

      if @error_count < @error_limit
        @error_count += 1
        @queue << current_download
      else
        @error_limit_passed = true
      end
    end
  end
end
