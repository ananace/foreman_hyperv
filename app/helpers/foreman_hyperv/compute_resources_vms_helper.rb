module ForemanHyperv
  module ComputeResourcesVmsHelper
    def hyperv_networks(compute_resource)
      compute_resource.switches(nil).map do |sw|
        [ sw.id, "#{sw.name}#{sw.switch_type ? " (#{sw.switch_type})" : nil}" ]
      end
    end

    def hyperv_generations
      Fog::Hyperv::Compute::Server::VM_GENERATION_VALUES.map { |gen, num| [gen, "Generation #{num} (#{gen})"] }
    end
    def hyperv_vlan_modes
      Fog::Hyperv::Compute::NetworkAdapterVlan::VLAN_OPERATION_MODE.map { |mode| [mode, mode] }
    end
    def hyperv_private_vlan_modes
      Fog::Hyperv::Compute::NetworkAdapterVlan::PRIVATE_VLAN_MODE.reject { |mode| mode == :Unknown }.map { |mode| [mode, mode] }
    end
  end
end
