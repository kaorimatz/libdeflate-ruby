# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'libdeflate/version'

Gem::Specification.new do |spec|
  spec.name          = 'libdeflate'
  spec.version       = Libdeflate::VERSION
  spec.authors       = ['Satoshi Matsumoto']
  spec.email         = ['kaorimatz@gmail.com']

  spec.summary       = 'Ruby bindings for libdeflate'
  spec.description   = 'Ruby bindings for libdeflate.'
  spec.homepage      = 'https://github.com/kaorimatz/libdeflate-ruby'
  spec.license       = 'MIT'

  spec.files = `git ls-files -z --recurse-submodules`.split("\x0").reject do |f|
    f.match(%r{^(benchmark|spec)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.extensions    = ['ext/libdeflate/extconf.rb']

  spec.add_runtime_dependency 'mini_portile2', '>= 2.2.0'

  spec.add_development_dependency 'benchmark-ips'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rake-compiler'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
end
