# frozen_string_literal: true

module ForemanHyperv
  module HostManagedExtensions
    extend ActiveSupport::Concern

    def update(attributes = {})
      if provider == 'Hyper-V' && attributes.key?('compute_attributes')
        add_hyperv_attributes(attributes)
        logger.debug "Expanded attributes to #{attributes}"
      end

      super
    end

    def setComputeUpdate
      return super unless provider == 'Hyper-V'

      attr = compute_attributes.dup

      super

      unmapped_ifaces = interfaces.select { |iface| iface.physical? && !iface.compute_attributes['identity'].present? }
      return if unmapped_ifaces.empty?

      logger.info "Mapping unknown interfaces after update for #{name}"

      self.vm = compute_object
      fog_nics = vm.interfaces.dup
      interfaces.each { |iface| fog_nics.delete_if { |vmiface| vmiface.id == iface.compute_attributes['identity'] } }

      unmapped_ifaces.each do |nic|
        logger.info "Matching #{nic.inspect} against #{fog_nics}"
        selected_nic = vm.select_nic(fog_nics, nic)
        if selected_nic.nil?
          logger.warn "Orchestration::Compute: Could not match network interface #{nic.inspect}"
          return failure(_("Could not find virtual machine network interface matching %s") % [nic.identifier, nic.ip, nic.name, nic.type].find(&:present?))
        end

        logger.debug "Orchestration::Compute: nic #{nic.inspect} assigned to #{selected_nic.inspect}"
        nic.mac ||= selected_nic.mac
        nic.save
      end
    end

    private

    def add_hyperv_attributes(attributes)
      compute = attributes['compute_attributes'] ||= {}
      compute['interfaces_attributes'] ||= {}

      attributes['interfaces_attributes'].each do |idx, interface|
        compute['interfaces_attributes'][idx] = interface
      end
    end
  end
end
