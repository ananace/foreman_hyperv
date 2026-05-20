# frozen_string_literal: true

module ForemanHyperv
  module HostManagedExtensions
    extend ActiveSupport::Concern

    def update(attributes = {})
      hyperv_add_attributes(attributes) if provider == 'Hyper-V' && attributes.key?('compute_attributes')

      super
    end

    def setComputeUpdate
      ret = super
      return ret unless provider == 'Hyper-V'

      begin
        hyperv_sync_interfaces
      rescue => e
        failure _("Failed to update a compute %{compute_resource} instance %{name}: %{e}") %
                { compute_resource:, name:, e: }, e
      end
      true
    end

    def hyperv_sync_interfaces
      unmapped_ifaces = interfaces.select { |iface| iface.physical? && !iface.compute_attributes['identity'].present? }
      return true if unmapped_ifaces.empty?

      logger.info "Mapping #{unmapped_ifaces.count} unknown interfaces for #{name}"

      self.vm = compute_object
      fog_nics = vm.interfaces.dup
      interfaces.each { |iface| fog_nics.delete_if { |vmiface| vmiface.id == iface.compute_attributes['identity'] } }

      unmapped_ifaces.each do |nic|
        logger.debug "Matching #{nic.inspect} against #{fog_nics}"
        selected_nic = vm.select_nic(fog_nics, nic)
        if selected_nic.nil?
          logger.warn "Orchestration::Compute: Could not match network interface #{nic.inspect}"
          raise ArgumentError, \
            _("Could not find virtual machine network interface matching %s") %
            [nic.identifier, nic.ip, nic.name, nic.type].find(&:present?)
        end

        logger.debug "Orchestration::Compute: nic #{nic.inspect} assigned to #{selected_nic.inspect}"
        nic.mac ||= selected_nic.mac
        nic.save
        fog_nics.delete selected_nic
      end
    end

    private

    # Inject interface attributes into the compute values, to allow modifying Hyper-V configuration on hosts
    def hyperv_add_attributes(attributes)
      compute = attributes['compute_attributes'] ||= {}
      compute['interfaces_attributes'] ||= {}

      attributes['interfaces_attributes'].each do |idx, interface|
        compute['interfaces_attributes'][idx] = interface
      end
    end
  end
end
