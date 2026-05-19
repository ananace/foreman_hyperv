# frozen_string_literal: true

module FogExtensions
  module Hyperv
    module NetworkAdapter
      extend ActiveSupport::Concern

      def mac
        return unless mac_address
        return if mac_address.to_i(16) == 0

        # Downcase and split every 2 chars, join with :
        mac_address.downcase.scan(%r{.{2}}).join(':')
      end

      def mac=(m)
        mac_address = m&.upcase&.delete(':')
        mac_address = Fog::Hyperv::Compute::NetworkAdapter::NIC_FALLBACK_MAC if mac_address.nil? || mac_address.blank?
        dynamic_mac_address_enabled = (mac_address.to_i(16) == 0)
      end

      # VLAN settings

      def vlan_operation_mode
        vlan_setting.operation_mode
      end
      def vlan_operation_mode=(mode)
        vlan_setting.operation_mode = mode
      end

      def vlan_private_mode
        return nil if vlan_setting.private_vlan_mode == :Unknown

        vlan_setting.private_vlan_mode
      end
      def vlan_private_mode=(mode)
        vlan_setting.private_vlan_mode = mode
      end

      def access_vlan_id
        return nil if vlan_setting.access_vlan_id.zero?

        vlan_setting.access_vlan_id
      end
      def access_vlan_id=(id)
        vlan_setting.access_vlan_id = id
      end

      def native_vlan_id
        return nil if vlan_setting.native_vlan_id.zero?

        vlan_setting.native_vlan_id
      end
      def native_vlan_id=(id)
        vlan_setting.native_vlan_id = id
      end

      def allowed_vlan_ids
        return nil unless vlan_setting.allowed_vlan_id_list&.any?

        vlan_setting.allowed_vlan_id_list.join ', '
      end
      def allowed_vlan_ids=(ids)
        ids ||= ''
        vlan_setting.allowed_vlan_id_list = ids.split(',').map(&:to_i)
      end

      def primary_vlan_id
        return nil if vlan_setting.primary_vlan_id.zero?

        vlan_setting.primary_vlan_id
      end
      def primary_vlan_id=(id)
        vlan_setting.primary_vlan_id = id
      end

      def secondary_vlan_id
        return nil if vlan_setting.secondary_vlan_id.zero?

        vlan_setting.secondary_vlan_id
      end
      def secondary_vlan_id=(id)
        vlan_setting.secondary_vlan_id = id
      end

      def secondary_vlan_ids
        return nil unless vlan_setting.secondary_vlan_id_list&.any?

        vlan_setting.secondary_vlan_id_list.join ', '
      end
      def secondary_vlan_ids=(ids)
        ids ||= ''
        vlan_setting.secondary_vlan_id_list = ids.split(',').map(&:to_i)
      end

      def compute_attributes
        attributes
          .slice(
            :id,
            :switch_id
          )
          .merge(
            {
              vlan_operation_mode:,
              vlan_private_mode:,
              access_vlan_id:,
              native_vlan_id:,
              allowed_vlan_ids:,
              primary_vlan_id:,
              secondary_vlan_id:,
              secondary_vlan_ids:
            }.compact
          )
      end
    end
  end
end
