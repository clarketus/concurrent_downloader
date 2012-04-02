require 'spec_helper'

describe ConcurrentDownloader do

  it "should raise when there is a connection error" do
    queue = []
    queue << "/test"

    lambda {
      ConcurrentDownloader.process_queue!(queue, :host => "http://not_a_host")
    }.should raise_exception(ConcurrentDownloader::DownloadError)
  end

  it "should process a basic queue" do
    queue = []
    queue << "/test"

    responses = []
    ConcurrentDownloader.process_queue!(queue, :host => $mock_host_uri) do |queue_item, response|
      responses << response
    end

    responses.size.should == 1
    response = responses.first

    response.status.should == 200
    response.headers.should == {"CONNECTION"=>"close", "CONTENT_LENGTH"=>"62"}
    Yajl.load(response.body).should == {
      "path"        => "/test",
      "body"        => nil,
      "method"      => "GET",
      "test_header" => nil
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
    response.headers.should == {"CONNECTION"=>"close", "CONTENT_LENGTH"=>"107"}
    Yajl.load(response.body).should == {
      "path"        => "/test",
      "body"        => "test_param_key=test_param_value",
      "method"      => "POST",
      "test_header" => "test_header_value"
    }
  end
end
