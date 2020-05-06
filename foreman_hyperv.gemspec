# frozen_string_literal: true

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
  spec.homepage      = 'https://github.com/ananace/foreman_hyperv'
  spec.license       = 'GPL-3.0'

  spec.files         = Dir['{app,config,db,lib,locale}/**/*']+%w[LICENSE.txt Rakefile README.md]
  spec.test_files    = spec.files.grep(%r{^test\/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'fog-hyperv', '~> 0.0.2'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest'
end
