module MockServerHelper
  def start_mock_server(&block)
    app = lambda {|env|
      request = Rack::Request.new(env)
      block.call(request)
    }

    port = find_available_port

    Thread.new do
      Puma::Server.new(app).tap do |s|
        s.add_tcp_listener '127.0.0.1', port
      end.run.join
    end

    URI.parse "http://127.0.0.1:#{port}"
  end

  def find_available_port
    server = TCPServer.new('127.0.0.1', 0)
    server.addr[1]
  ensure
    server.close if server
  end
end

