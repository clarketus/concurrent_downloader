# -*- encoding: utf-8 -*-
require File.expand_path('../lib/concurrent_downloader/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Oliver Clarke"]
  gem.email         = ["ollie@clarketus.net"]
  gem.description   = %q{Concurrently download http requests in a synchronous environment.}
  gem.summary       = %q{A basic em-http-request wrapper that slots into a normal ruby script.}
  gem.homepage      = ""

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "concurrent_downloader"
  gem.require_paths = ["lib"]
  gem.version       = ConcurrentDownloader::VERSION

  gem.add_dependency('eventmachine')
  gem.add_dependency('em-http-request')
end

