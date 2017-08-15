module ForemanHyperv
  class Engine < ::Rails::Engine
    engine_name 'foreman_hyperv'

    initializer 'foreman_hyperv.register_plugin', :before => :finisher_hook do
      Foreman::Plugin.register :foreman_hyperv do
        requires_foreman '>= 1.14'
        compute_resource ForemanHyperv::Hyperv
      end
    end

    config.to_prepare do
      require 'fog/hyperv'

      require 'fog/hyperv/models/compute/server'
      require File.expand_path(
        '../../../app/models/concerns/fog_extensions/hyperv/server', __FILE__)
      Fog::Compute::Hyperv::Server.send(:include, FogExtensions::Hyperv::Server)

      require 'fog/hyperv/models/compute/network_adapter'
      require File.expand_path(
        '../../../app/models/concerns/fog_extensions/hyperv/network_adapter', __FILE__)
      Fog::Compute::Hyperv::NetworkAdapter.send(:include, FogExtensions::Hyperv::NetworkAdapter)
    end
  end
end
