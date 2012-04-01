require 'concurrent_downloader'
require 'puma'

Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  config.include MockServerHelper

  config.before :suite do
    ConcurrentDownloader.logger = Logger.new($stdout)
  end
end

