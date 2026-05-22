# frozen_string_literal: true

module ForemanHyperv
  module ComputeResourcesVmsHelper
    def hyperv_networks(compute_resource)
      compute_resource.switches(nil).map do |sw|
        [sw.id, "#{sw.name}#{" (#{sw.switch_type})" if sw.switch_type}"]
      end
    end

    def hyperv_boot_devices
      devices = Fog::Hyperv::BOOT_DEVICE_ENUM_VALUES.dup
      # devices.delete :Floppy if generation == :UEFI
      devices.delete :IDE
      devices.delete :LegacyNetworkAdapter
      devices.map do |dev|
        name = dev.to_s
        name = 'Network Adapter' if dev == :NetworkAdapter
        name = 'DVD' if dev == :CD
        name = 'Floppy (Only for BIOS)' if dev == :Floppy
        [dev, name]
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
