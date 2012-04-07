require 'spec_helper'

describe ConcurrentDownloader do

  context "Basic operation" do
    it "should process a basic queue" do
      queue = []
      queue << "/test"

      responses = []
      ConcurrentDownloader.process_queue!(queue, :host => $mock_host_uri) do |queue_item, response|
        responses << response
      end

      responses.size.should == 1
      response = responses.first

      response.should be_a(ConcurrentDownloader::Response)
      response.status.should == 200
      response.headers.should == {"CONNECTION"=>"close", "CONTENT_LENGTH"=>"82"}
      Yajl.load(response.body).should == {
        "path"          => "/test",
        "body"          => nil,
        "downloader_id" => "0",
        "method"        => "GET",
        "test_header"   => nil
      }
    end

    it "should allow setting of specific request options" do
      queue = []
      queue << {
        :method => "post",
        :path   => "/test",
        :body   => {"test_param_key" => "test_param_value"},
        :head   => {"test_header_key" => "test_header_value"}
      }

      responses = []
      ConcurrentDownloader.process_queue!(queue, :host => $mock_host_uri) do |queue_item, response|
        responses << response
      end

      responses.size.should == 1
      response = responses.first

      response.status.should == 200
      response.headers.should == {"CONNECTION"=>"close", "CONTENT_LENGTH"=>"127"}
      Yajl.load(response.body).should == {
        "path"          => "/test",
        "body"          => "test_param_key=test_param_value",
        "downloader_id" => "0",
        "method"        => "POST",
        "test_header"   => "test_header_value"
      }
    end
  end

  context "large queues" do
    it "should process a large queue" do
      queue = []
      100.times do |i|
        queue << {
          :method => "post",
          :path   => "/test",
          :body   => {"request_number" => "%03d" % i},
        }
      end

      responses = []
      ConcurrentDownloader.process_queue!(queue, :host => $mock_host_uri) do |queue_item, response|
        responses << response
      end

      responses.size.should == 100

      responses.reverse.each_with_index do |response, index|
        response.status.should == 200
        response.headers.should == {"CONNECTION"=>"close", "CONTENT_LENGTH"=>"99"}
        Yajl.load(response.body).should == {
          "path"          => "/test",
          "body"          => "request_number=#{"%03d" % index}",
          "downloader_id" => "0",
          "method"        => "POST",
          "test_header"   => nil
        }
      end
    end

    it "should allow concurrent requests" do
      queue = []
      100.times do |i|
        queue << {
          :method => "post",
          :path   => "/test"
        }
      end

      responses = []
      ConcurrentDownloader.process_queue!(queue, :host => $mock_host_uri, :concurrent_downloads => 10) do |queue_item, response|
        responses << response
      end

      downloader_ids = []

      responses.size.should == 100
      responses.each do |response|
        response.status.should == 200
        response.headers.should == {"CONNECTION"=>"close", "CONTENT_LENGTH"=>"81"}
        body = Yajl.load(response.body)
        body["path"].should == "/test"
        body["method"].should == "POST"

        downloader_ids << body["downloader_id"].to_i
      end

      (0..9).each{|i| downloader_ids.should include(i) }
    end
  end

  context "Error handling" do
    it "should raise when there is a connection error" do
      port = find_available_port

      queue = []
      queue << "/test"

      exception = nil
      begin
        ConcurrentDownloader.process_queue!(queue, :host => "http://127.0.0.1:#{port}")
      rescue => e
        exception = e
      end

      exception.should_not be_nil
      exception.should be_a(ConcurrentDownloader::ConnectionError)
      exception.message.should == "There was a connection error: GET /test"
    end

    it "should raise when there is an inactivity timeout" do
      begin
        server = TCPServer.new('127.0.0.1', 0)
        port = server.addr[1]

        queue = []
        queue << "/test"

        exception = nil
        begin
          ConcurrentDownloader.process_queue!(queue, :host => "http://127.0.0.1:#{port}", :inactivity_timeout => 1)
        rescue => e
          exception = e
        end

        exception.should_not be_nil
        exception.should be_a(ConcurrentDownloader::ConnectionError)
        exception.message.should == "There was a connection error: GET /test"
      ensure
        server.close if server
      end
    end

    it "should raise a download error when request block returns false" do
      queue = []
      queue << "/test"

      exception = nil

      begin
        ConcurrentDownloader.process_queue!(queue, :host => $mock_host_uri) do |queue_item, response|
          false
        end
      rescue => e
        exception = e
      end

      exception.should_not be_nil
      exception.should be_a(ConcurrentDownloader::DownloadError)
      exception.message.should == "There was a download error: GET /test: 200"
    end

    it "should retry downloading if an error occurs and the limit is not reached" do
      queue = []
      10.times do
        queue << "/test"
      end

      responses = []

      count = 0
      ConcurrentDownloader.process_queue!(queue, :host => $mock_host_uri, :error_limit => 20) do |queue_item, response|
        count += 1
        if count > 20
          responses << response
        end

        count > 20
      end

      count.should == 30 # 30 total requests
      responses.size.should == 10 # 10 succeeded
      responses.each do |response|
        response.status.should == 200
      end
    end

    it "should raise an error if the limit is reached and cancel all downloads in the queue" do
      queue = []
      10.times do
        queue << "/test"
      end

      responses = []
      exception = nil

      begin
        count = 0
        ConcurrentDownloader.process_queue!(queue, :host => $mock_host_uri, :error_limit => 20) do |queue_item, response|
          count += 1
          if count < 5
            responses << response
          end

          count < 5
        end
      rescue => e
        exception = e
      end

      exception.should_not be_nil
      exception.should be_a(ConcurrentDownloader::DownloadError)
      exception.message.should == "There was a download error: GET /test: 200"

      count.should == 25 # 25 total requests
      responses.size.should == 4 # 4 succeeded
      responses.each do |response|
        response.status.should == 200
      end
    end
  end
end

