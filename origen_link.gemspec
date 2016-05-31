# coding: utf-8
config = File.expand_path('../config', __FILE__)
require "#{config}/version"

Gem::Specification.new do |spec|
  spec.name          = "origen_link"
  spec.version       = OrigenLink::VERSION
  spec.authors       = ["Paul Derouen"]
  spec.email         = ["paul.derouen@nxp.com"]
  spec.summary       = "Origen interface to a live DUT tester"
  spec.homepage      = "http://origen-sdk.org/OrigenLink"

  spec.required_ruby_version     = '>= 1.9.3'
  spec.required_rubygems_version = '>= 1.8.11'

  # Only the files that are hit by these wildcards will be included in the
  # packaged gem, the default should hit everything in most cases but this will
  # need to be added to if you have any custom directories
  spec.files         = Dir["lib/**/*.rb", "templates/**/*", "config/**/*.rb",
                           "bin/*", "lib/tasks/**/*.rake", "pattern/**/*.rb",
                           "program/**/*.rb"
                          ]
  spec.executables   = ["start_link_server"]
  spec.require_paths = ["lib"]

  # Add any gems that your plugin needs to run within a host application
  spec.add_runtime_dependency 'origen', '>= 0.7.2'
  spec.add_runtime_dependency 'origen_testers', '>= 0.6.1'
  spec.add_runtime_dependency 'sinatra', '~> 1'
end
