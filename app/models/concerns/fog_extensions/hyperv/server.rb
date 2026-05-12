module FogExtensions
  module Hyperv
    module Server
      extend ActiveSupport::Concern
      include ActionView::Helpers::NumberHelper

      def to_s
        name
      end

      def folder_name
        name.gsub(/[^0-9A-Za-z.\-]/, '_')
      end

      def mac
        network_adapters.first.mac
      end

      def interfaces
        network_adapters
      end

      def volumes
        hard_drives
      end

      def interfaces_attributes=(_attributes)
        true
      end

      def volumes_attributes=(_attributes); end

      # Override fog configuration with explicit cluster_name handling
      def cluster
        @cluster
      end

      def cluster_name
        cluster&.name
      end

      def cluster_name=(name)
        @cluster = service.clusters.get(name)
      end
      #

      def vlan
        nic = network_adapters.first

        nic.access_vlan_id || nic.native_vlan_id || nic.primary_vlan_id
      end

      def vlan=(vlan)
        logger.warn "using vlan=#{vlan.inspect} on Hyper-V VM, this can lead to unexpected results"
        nic = network_adapters.first
        if vlan.present? && vlan.to_i > 0
          nic.vlan_operation_mode = :Access if nic.vlan_operation_mode == :Untagged
          case nic.vlan_operation_mode
          when :Access
            nic.access_vlan_id = vlan
          when :Trunk
            nic.native_vlan_id = vlan
          when :Private
            nic.primary_vlan_id = vlan
          end
        else
          nic.vlan_operation_mode = :Untagged
        end
      end

      def secure_boot_enabled=(enabled)
        return if generation != :UEFI

        @secure_boot = enabled
        return unless persisted?

        firmware.secure_boot = enabled ? :On : :Off
      end

      def secure_boot_enabled
        return false if generation != :UEFI
        return @secure_boot unless persisted?

        firmware.secure_boot == :On
      end

      def vm_description
        format _('%{cpus} CPUs and %{ram} memory'),
               cpus: processor_count,
               ram: number_to_human_size(memory_startup)
      end

      def select_nic(fog_nics, nic)
        nic_attrs = nic.compute_attributes
        match =   fog_nics.detect { |fn| fn.id == nic_attrs['id'] } # Check the id
        match ||= fog_nics.detect { |fn| fn.name == nic_attrs['name'] } # Check the name
        match ||= fog_nics.detect { |fn| fn.switch_name == nic_attrs['switch_name'] } # Fall back to the switch name
        match
      end
    end
  end
end
