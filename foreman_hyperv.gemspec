# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'foreman_hyperv/version'

Gem::Specification.new do |spec|
  spec.name          = 'foreman_hyperv'
  spec.version       = ForemanHyperv::VERSION
  spec.authors       = ['Alexander Olofsson']
  spec.email         = ['alexander.olofsson@liu.se']

  spec.summary       = 'Hyper-V as a Compute Resource for Foreman'
  spec.description   = 'Hyper-V as a Compute Resource for Foreman'
  spec.homepage      = 'https://github.com/ace13/foreman_hyperv'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^test\/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'fog-hyperv', '~> 0.0.1'

  spec.add_development_dependency 'bundler', '~> 1.13'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
end
