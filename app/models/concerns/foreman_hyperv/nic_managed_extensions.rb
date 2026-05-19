# frozen_string_literal: true

module ForemanHyperv
  module NicManagedExtensions
    extend ActiveSupport::Concern

    prepended do
      after_validation :save_hyperv_changes
    end

    def hyperv_object
      return unless is_hyperv_nic? && compute_attributes.deep_symbolize_keys[:identity]

      host.compute_object.network_adapters.get compute_attributes.deep_symbolize_keys[:identity]
    end

    def save_hyperv_changes
      return unless errors.empty? && is_hyperv_nic? && compute_attributes_changed?

      nic = hyperv_object
      return unless nic

      compute_attributes.except(:identity, 'identity').each do |k, v|
        nic.send :"#{k}=", v
      end
      nic.save
    end

    private

    def is_hyperv_nic?
      return false unless physical?
      return false unless host.uuid
      return false unless compute_resource.is_a? ForemanHyperv::Hyperv

      true
    end
  end
end
