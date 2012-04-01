module ConcurrentDownloader
  class Processor

    def process_queue!(queue, options={}, &block)
      @queue                = queue || []
      @error_limit          = options[:error_limit] || 10
      @concurrent_downloads = options[:concurrent_downloads] || 10
      @host                 = options[:host]
      @connect_timeout      = options[:connect_timeout] || 5
      @inactivity_timeout   = options[:inactivity_timeout] || 10

      @error_count = 0
      @error_limit_passed = false
      @response_block = block

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

        connection = EM::HttpRequest.new(@host, :connect_timeout => @connect_timeout, :inactivity_timeout => @inactivity_timeout)
        http = connection.send(method, :path => path, :body => body, :head => head)
        http.callback do |http|
          if http.response_header.status == 200
            @response_block.call(queue_item, http.response)
            recursive_download
          elsif http.response_header.status == 404
            recursive_download
          else
            handle_error(http, queue_item)
          end
        end
        http.errback do |http|
          handle_error(http, queue_item)
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

    def handle_error(http, current_download)
      ConcurrentDownloader.logger.info "Error received: #{http.response_header.status} #{http.inspect}"

      if @error_count < @error_limit
        @error_count += 1
        @queue << current_download
      else
        @error_limit_passed = true
      end

      recursive_download
    end
  end
end
