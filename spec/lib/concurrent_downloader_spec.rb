require 'spec_helper'

describe ConcurrentDownloader do
  before do
    @host_uri = start_mock_server do |request|
      [200, [], ["response for path: #{request.path}"]]
    end
  end

  it "should download stuff" do
    queue = []
    queue << {:path => "/test"}

    responses = []
    ConcurrentDownloader.process_queue!(queue, :host => @host_uri, :concurrent_downloads => 1, :error_limit => 0) do |queue_item, response|
      responses << response
    end

    responses.size.should == 1
    responses.first.should == "response for path: /test"
  end
end
