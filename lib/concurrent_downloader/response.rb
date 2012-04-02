module ConcurrentDownloader
  class Response
    attr_reader \
      :body,
      :status,
      :headers

    def initialize(data={})
      @body     = data[:body]
      @status   = data[:status]
      @headers  = data[:headers]
    end
  end
end
