require 'concurrent_downloader'
require 'puma'
require 'yajl'

Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each {|f| require f}

include MockServerHelper

RSpec.configure do |config|

  config.before :suite do
    ConcurrentDownloader.logger = Logger.new($stdout)

    $host_uri = start_mock_server do |request|
      body = {
        :path         => request.path,
        :body         => (request.post? ? request.body.read : nil),
        :method       => request.request_method,
        :test_header  => request.env["HTTP_TEST_HEADER_KEY"]
      }

      [200, [], [Yajl.dump(body)]]
    end
  end
end

