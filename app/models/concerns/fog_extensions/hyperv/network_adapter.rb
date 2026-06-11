# frozen_string_literal: true

module FogExtensions
  module Hyperv
    module NetworkAdapter
      extend ActiveSupport::Concern

      def mac
        return unless mac_address
        return if mac_address.to_i(16).zero?

        # Downcase and split every 2 chars, join with :
        mac_address.downcase.scan(/.{2}/).join(':')
      end

      def mac=(m)
        mac_address = m&.upcase&.delete(':')
        mac_address = Fog::Hyperv::Compute::NetworkAdapter::NIC_FALLBACK_MAC if mac_address.nil? || mac_address.blank?
        mac_address.to_i(16)
        0
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
        return nil if (vlan_setting.access_vlan_id || 0).zero?

        vlan_setting.access_vlan_id
      end

      delegate :access_vlan_id=, to: :vlan_setting

      def native_vlan_id
        return nil if (vlan_setting.native_vlan_id || 0).zero?

        vlan_setting.native_vlan_id
      end

      delegate :native_vlan_id=, to: :vlan_setting

      def allowed_vlan_ids
        return nil unless vlan_setting.allowed_vlan_id_list&.any?

        Fog::Hyperv::Compute::NetworkAdapterVlan.render_vlan_list vlan_setting.allowed_vlan_id_list
      end

      def allowed_vlan_ids=(ids)
        ids ||= ''
        vlan_setting.allowed_vlan_id_list = parse_vlan_list(ids)
      end

      def primary_vlan_id
        return nil if (vlan_setting.primary_vlan_id || 0).zero?

        vlan_setting.primary_vlan_id
      end

      delegate :primary_vlan_id=, to: :vlan_setting

      def secondary_vlan_id
        return nil if (vlan_setting.secondary_vlan_id || 0).zero?

        vlan_setting.secondary_vlan_id
      end

      delegate :secondary_vlan_id=, to: :vlan_setting

      def secondary_vlan_ids
        return nil unless vlan_setting.secondary_vlan_id_list&.any?

        Fog::Hyperv::Compute::NetworkAdapterVlan.render_vlan_list vlan_setting.secondary_vlan_id_list
      end

      def secondary_vlan_ids=(ids)
        ids ||= ''
        vlan_setting.secondary_vlan_id_list = parse_vlan_list(ids)
      end

      def compute_attributes
        attributes
          .slice(
            :id,
            :switch_id
          )
          .merge(
            vlan_setting.attributes.slice(
              :vlan_operation_mode,
              :vlan_private_mode,
              :access_vlan_id,
              :native_vlan_id,
              :primary_vlan_id,
              :secondary_vlan_id
            )
          )
          .merge(
            secondary_vlan_ids: secondary_vlan_ids,
            allowed_vlan_ids: allowed_vlan_ids
          )
          .compact
      end

      private

      def parse_vlan_list(list)
        ret = []
        list.split(',').map do |num|
          if num.include? '-'
            rstart, rend = num.split('-')
            ret += (rstart.to_i..rend.to_i).to_a
          else
            ret << num.to_i
          end
        end
        ret.sort.uniq
      end
    end
  end
end
