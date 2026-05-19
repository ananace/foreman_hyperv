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

      def interfaces_attributes=(_attributes); end

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

      def compute_attributes
        attributes.merge(
          interfaces_attributes: vm.network_adapters.each_with_index.to_h { |nic, idx| [idx, nic.compute_attributes] },
          volumes_attributes: vm.hard_drives.each_with_index.to_h { |hdd, idx| [idx, hdd.compute_attributes] }
        )
      end

      def select_nic(fog_nics, nic)
        nic_attrs = nic.compute_attributes

        # Match for exact data
        match   = fog_nics.detect { |fn| fn.id == nic_attrs['id'].presence }
        match ||= fog_nics.detect { |fn| fn.mac == nic.mac }
        # match ||= fog_nics.detect { |fn| fn.name == nic_attrs['name'].presence }

        if !match
          # Match on networking, limit potentials down to identical configuration and then pick the first
          potential = fog_nics.select do |fn|
            fn.switch_id == nic_attrs['switch_id'].presence || fn.switch_name == nic_attrs['switch_name'].presence
          end
          potential.select! { |fn| fn.vlan_operation_mode.to_s == nic_attrs['vlan_operation_mode'] }
          if nic_attrs['vlan_operation_mode'] == 'Access'
            potential.select! { |fn| fn.access_vlan_id.to_s == nic_attrs['access_vlan_id'] }
          elsif nic_attrs['vlan_operation_mode'] == 'Trunk'
            potential.select! { |fn| fn.native_vlan_id.to_s == nic_attrs['native_vlan_id'] }
            potential.select! { |fn| fn.allowed_vlan_ids.split(',').map(&:strip) == nic_attrs['allowed_vlan_ids'].split(',').map(&:strip) } \
              if nic_attrs['allowed_vlan_ids'].present?
          elsif nic_attrs['vlan_operation_mode'] == 'Private'
            potential.select! { |fn| fn.vlan_private_mode.to_s == nic_attrs['vlan_private_mode'] }
            potential.select! { |fn| fn.primary_vlan_id.to_s == nic_attrs['primary_vlan_id'].to_s } \
              if nic_attrs['primary_vlan_id'].present?

            if nic_attrs['vlan_private_mode'] == 'Promiscuous'
              potential.select! { |fn| fn.secondary_vlan_ids.split(',').map(&:strip) == nic_attrs['secondary_vlan_ids'].split(',').map(&:strip) } \
                if nic_attrs['secondary_vlan_ids'].present?
            else
              potential.select! { |fn| fn.secondary_vlan_id.to_s == nic_attrs['secondary_vlan_id'].to_s } \
                if nic_attrs['secondary_vlan_id'].present?
            end
          end

          match = potential.first
        end
        return unless match

        # Store Hyper-V ID in compute attributes
        nic.compute_attributes['identity'] = match.id

        match
      end
    end
  end
end
