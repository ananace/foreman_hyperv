# frozen_string_literal: true

module ForemanHyperv
  class Hyperv < ::ComputeResource
    include ComputeResourceCaching

    validates :url, :user, :password, presence: true
    after_validation :validate_connectivity unless Rails.env.test?

    def self.provider_friendly_name
      'Hyper-V'
    end

    def to_label
      "#{name} (#{provider_friendly_name})"
    end

    def self.available?
      Fog::Compute.providers.include?(:hyperv)
    end

    def self.model_name
      ComputeResource.model_name
    end

    def supports_update?
      true
    end

    def editable_network_interfaces?
      true
    end

    def capabilities
      [:build]
    end

    def test_connection(options = {})
      validate_connectivity(options)
    end

    def validate_connectivity(_options = {})
      return unless connection_properties_valid?
      return false if errors.any?

      client.valid?
    rescue Fog::Hyperv::Errors::ServiceError, ArgumentError, WinRM::WinRMAuthorizationError => e
      errors.add(:base, e.message)
    end

    def connection_valid?
      return false if url.blank? || user.blank? || password.blank?

      client&.valid?
    rescue StandardError
      false
    end

    def connection_properties_valid?
      errors[:url].empty? && errors[:user].empty? && errors[:password].empty?
    end

    def caching_enabled
      true
    end

    def provided_attributes
      super.merge(mac: :mac)
    end

    # TODO
    def max_cpu_count(host = nil)
      (host || hypervisor).logical_processor_count
    end

    def max_memory(host = nil)
      (host || hypervisor).memory_capacity
    end

    def available_hypervisors
      client.hosts.load(
        cache.cache(:available_hypervisor) do
          client.hosts.all.map(&:attributes)
        end
      )
    end
    alias hosts available_hypervisors

    def cluster(name)
      return nil unless name

      client.clusters.get name
    end

    def clusters
      client.clusters.load(
        cache.cache(:clusters) do
          _clusters.map(&:attributes)
        end
      )
    end

    def hypervisor
      client.hosts.new(
        cache.cache(:hypervisor) do
          client.hosts.first.attributes
        end
      )
    end

    delegate :servers, to: :client

    def switches(host)
      host ||= hosts.first
      client.switches.load(
        cache.cache(:"#{host.name}-switches") do
          host.switches.all.map(&:attributes)
        end
      )
    end

    def new_vm(attr = {})
      firmware_type = attr.delete(:firmware_type).to_s
      attr.merge!(process_firmware_attributes(attr[:foreman_firmware], firmware_type)) #, attr[:provision_method]))
      attr.delete :id
      vm = super
      iface_nested_attrs = nested_attributes_for :interfaces, attr[:interfaces_attributes]
      vm.network_adapters = iface_nested_attrs.map do |attr|
        attr.delete :id
        Fog::Hyperv::Compute::NetworkAdapter.new(service: vm.service, vm: vm).tap do |nic|
          attr.select { |_, v| v.present? }.each do |k, v|
            nic.send(:"#{k}=", v)
          end
        end
      end
      volume_nested_attrs = nested_attributes_for :volumes, attr[:volumes_attributes]
      vm.hard_drives = volume_nested_attrs.map do |attr|
        attr.delete :id
        Fog::Hyperv::Compute::HardDrive.new(service: vm.service, vm: vm).tap do |hdd|
          attr.select { |_, v| v.present? }.each do |k, v|
            hdd.send(:"#{k}=", v)
          end
        end
      end
      vm.id = nil
      vm
    end

    def create_vm(attr = {})
      attr = vm_instance_defaults.merge(attr.to_hash.deep_symbolize_keys)
      attr.delete :computer_name if attr[:computer_name].blank?
      attr.delete :start

      firmware_type = attr.delete(:firmware_type).to_s
      attr.merge!(process_firmware_attributes(attr[:foreman_firmware], firmware_type)) #, attr[:provision_method]))
      attr[:tpm_enabled] = attr.delete(:tpm_enabled) == '1' if attr['tpm_enabled'].present?

      validate_vm(attr, new: true)
      validate_interfaces(attr)
      validate_volumes(attr)

      vm = client.servers.new(
        name: attr[:name],
        computer_name: attr[:computer_name],
        generation: attr[:generation],
        dynamic_memory_enabled: Foreman::Cast.to_bool(attr[:dynamic_memory_enabled]),
        memory_startup: attr[:memory_startup].to_i,
        memory_minimum: attr[:memory_minimum].to_i,
        memory_maximum: attr[:memory_maximum].to_i,
        processor_count: attr[:processor_count].to_i,
        notes: attr[:notes]
      )
      vm.create(
        boot_device: attr[:boot_device].present? ? attr[:boot_device].to_sym : :NetworkAdapter
      )

      if vm.generation == :UEFI && attr[:secure_boot_enabled].present?
        f = vm.bios
        f.secure_boot = Foreman::Cast.to_bool(attr[:secure_boot_enabled]) ? :On : :Off
        f.save if f.dirty?
      end

      create_interfaces(vm, attr)
      create_volumes(vm, attr)

      vm.start if attr[:start] == '1'
      vm
    rescue StandardError => e
      if vm
        vm.stop
        vm.hard_drives.each { |hdd| hdd.destroy(underlying: true) }
        vm.destroy
      end

      raise e
    end

    def save_vm(uuid, web_attr)
      attr = web_attr.deep_symbolize_keys

      validate_vm(attr)
      validate_interfaces(attr)
      validate_volumes(attr)

      attr.delete :start

      vm = find_vm_by_uuid(uuid)
      logger.debug "Updating VM #{vm} with arguments; #{attr}"

      vm.processor_count = attr[:processor_count].to_i
      vm.notes = attr[:notes].presence
      vm.dynamic_memory_enabled = Foreman::Cast.to_bool(attr[:dynamic_memory_enabled])
      if vm.dynamic_memory_enabled
        vm.memory_minimum = attr[:memory_minimum].to_i
        vm.memory_maximum = attr[:memory_maximum].to_i
      end
      # if vm.generation == :UEFI && attr[:secure_boot_enabled].present?
      #   f = vm.bios
      #   f.secure_boot = Foreman::Cast.to_bool(attr[:secure_boot_enabled]) ? :On : :Off
      #   f.save if f.dirty?
      # end

      update_interfaces(vm, attr)
      update_volumes(vm, attr)

      vm.save if vm.dirty?
      vm
    end

    def destroy_vm(uuid)
      vm = find_vm_by_uuid(uuid)
      vm.stop turn_off: true
      vm.hard_drives.each { |hdd| hdd.destroy(underlying: true) }
      # TODO: Remove the empty VM folder
      vm.destroy
    rescue ActiveRecord::RecordNotFound, Fog::Errors::NotFound
      # if the VM does not exists, we don't really care.
      true
    end

    def update_required?(old_attrs, new_attrs)
      new_attrs.deep_symbolize_keys[:volumes_attributes]&.each_value do |hdd|
        if hdd[:id].present? && hdd[:_delete] == '1'
          Rails.logger.debug 'Scheduling compute instance update because a volume was removed'
          return true
        elsif hdd[:id].blank? && hdd[:_delete] != '1'
          Rails.logger.debug 'Scheduling compute instance update because a new volume was added'
          return true
        end
      end
      new_attrs.deep_symbolize_keys[:interfaces_attributes]&.each_value do |iface|
        if iface[:id].present? && iface[:_destroy] == '1'
          Rails.logger.debug 'Scheduling compute instance update because an interface was removed'
          return true
        elsif iface[:id].blank? && iface[:_destroy] != '1'
          Rails.logger.debug 'Scheduling compute instance update because a new interface was added'
          return true
        end
      end

      deep_update_required = proc do |old, new|
        old.merge(new) do |k, old_v, new_v|
          if %i[allowed_vlan_ids secondary_vlan_ids].include?(k)
            tmp = Fog::Hyperv::Compute::NetworkAdapter.new

            old_v = Fog::Hyperv::Compute::NetworkAdapterVlan.render_vlan_list(tmp.send(:parse_vlan_list, old_v.to_s))
            new_v = Fog::Hyperv::Compute::NetworkAdapterVlan.render_vlan_list(tmp.send(:parse_vlan_list, new_v.to_s))
          end

          if old_v.is_a?(Hash) && new_v.is_a?(Hash)
            deep_update_required.call(old_v, new_v)
          elsif old_v.to_s != new_v.to_s
            Rails.logger.debug do
              "Scheduling compute instance update because #{k} changed it's value from '#{old_v}' (#{old_v.class}) to '#{new_v}' (#{new_v.class})"
            end
            return true
          end
          new_v
        end
      end
      deep_update_required.call(old_attrs.deep_symbolize_keys, new_attrs.deep_symbolize_keys)

      false
    end

    # def console(uuid)
    #   vm = find_vm_by_uuid(uuid)
    #
    #   {
    #     type: 'rdp',
    #     host: vm.computer.fully_qualified_domain_name,
    #   }
    # end

    def new_interface(attr = {})
      Fog::Hyperv::Compute::NetworkAdapter.new attr
    end

    def new_volume(attr = {})
      basename = attr.delete(:basename) { 'Disk' }
      size = attr.delete(:size)

      vhd = client.vhds.new({ basename: basename, size: size }.compact)
      Fog::Hyperv::Compute::HardDrive.new vhd: vhd, **attr
    end

    def new_cdrom(attr = {})
      Fog::Hyperv::Compute::DvdDrive.new attr
    end

    def vm_instance_defaults
      super.merge(
        generation: 2,
        memory_startup: 1024.megabytes,
        processor_count: 1,
        interfaces: [new_interface]
      )
    end

    def set_vm_volumes_attributes(vm, vm_attrs)
      volumes = vm.hard_drives || []
      vm_attrs[:volumes_attributes] = volumes.each_with_index.to_h do |volume, index|
        [index.to_s, volume.compute_attributes]
      end
      vm_attrs
    end

    def set_vm_interfaces_attributes(vm, vm_attrs)
      interfaces = vm.interfaces || []
      vm_attrs[:interfaces_attributes] = interfaces.each_with_index.to_h do |interface, index|
        interface_attrs = {
          mac: interface.mac,
          compute_attributes: interface.compute_attributes
        }
        [index.to_s, interface_attrs]
      end
      vm_attrs
    end

    protected

    def client
      @client ||= Fog::Compute.new(
        provider: :HyperV,
        hyperv_endpoint: url,
        hyperv_username: user,
        hyperv_password: password
      )
    end

    private

    def _clusters
      return [] if client.respond_to?(:supports_clusters?) && !client.supports_clusters?

      client.clusters.all
    rescue StandardError
      []
    end

    def validate_vm(attr, new: false)
      # logger.debug "Validate VM #{attr.inspect}"
      raise Foreman::Exception, 'VM lacks generation' if new && attr[:generation].blank?
      raise Foreman::Exception, 'VM lacks memory' unless attr[:memory_startup].to_i.positive?
      raise Foreman::Exception, 'VM lacks CPUs' unless attr[:processor_count].to_i.positive?

      return unless Foreman::Cast.to_bool(attr[:dynamic_memory_enabled])
      raise Foreman::Exception, 'VM lacks memory minimum' unless attr[:memory_minimum].to_i.positive?
      raise Foreman::Exception, 'VM lacks memory maximum' unless attr[:memory_maximum].to_i.positive?
    end

    def generate_secure_boot_settings(firmware)
      return {} unless firmware == 'uefi_secure_boot'

      {
        secure_boot_enabled: true
      }
    end

    def validate_interfaces(attr)
      interfaces = nested_attributes_for :interfaces, attr[:interfaces_attributes]
      interfaces.reject! { |iface| iface[:_destroy] == '1' }
      # logger.debug "Validate NIC #{interfaces.inspect}"
      interfaces.each do |iface|
        compute = iface[:compute_attributes] || iface
        case compute[:vlan_operation_mode].to_s
        when 'Untagged'
          # No VLAN settings to verify
        when 'Access'
          raise Foreman::Exception, 'Interface is missing access VLAN' unless compute[:access_vlan_id].to_i.positive?
        when 'Trunk'
          raise Foreman::Exception, 'Interface is missing native VLAN' unless compute[:native_vlan_id].to_i.positive?
          raise Foreman::Exception, 'Interface is missing allowed VLANs' if compute[:allowed_vlan_ids].blank?
        when 'Private'
          raise Foreman::Exception, 'Interface is missing primary VLAN' unless compute[:primary_vlan_id].to_i.positive?

          case compute[:vlan_private_mode].to_s
          when 'Promiscuous'
            if compute[:secondary_vlan_ids].blank?
              raise Foreman::Exception,
                    'Interface is missing secondary VLANs'
            end
          else
            unless compute[:secondary_vlan_id].to_i.positive?
              raise Foreman::Exception,
                    'Interface is missing secondary VLAN'
            end
          end
        else
          raise Foreman::Exception, 'Interface has unknown VLAN mode'
        end
      end
    end

    def create_interfaces(vm, attr)
      interfaces = nested_attributes_for :interfaces, attr[:interfaces_attributes]
      logger.debug "Creating interfaces with: #{interfaces}"

      first_provisioned = false
      interfaces.each do |iface|
        # The VM is pre-created with one NIC regardless of given creation options, so configure that one first
        nic = vm.network_adapters.first unless first_provisioned
        first_provisioned = true

        nic ||= vm.network_adapters.new
        iface.except(:identity, :ip, :ip6).each do |k, v|
          nic.send(:"#{k}=", v.presence)
        end
        # nic.is_legacy = Foreman::Cast.to_bool(iface[:is_legacy]) if vm.generation == :BIOS && iface[:is_legacy].present?
        # logger.debug "Creating interface with #{iface.inspect} - #{nic.inspect}\n#{nic.vlan_setting.inspect}"
        nic.save
      end

      unless vm.network_adapters.all(_return_fields: %i[dynamic_mac_address_enabled]).any?(&:dynamic_mac_address_enabled)
        return
      end

      # Populate all non-populated MAC addresses
      vm.start
      vm.stop turn_off: true

      vm.network_adapters.reload.each do |nic|
        nic.dynamic_mac_address_enabled = false
        nic.save if nic.dirty?
      end
    end

    def update_interfaces(vm, attr)
      interfaces = nested_attributes_for :interfaces, attr[:interfaces_attributes]
      logger.debug "Updating interfaces with: #{interfaces}"

      interfaces.each do |interface|
        compute = interface[:compute_attributes]
        if compute[:identity].present?
          nic = vm.network_adapters.get compute[:identity]
          if interface[:_destroy] == '1'
            nic.destroy
          else
            compute.each do |k, v|
              nic.send(:"#{k}=", v.presence)
            end
            nic.mac ||= interface[:mac].presence
            nic.save
          end
        elsif interface[:_destroy] != '1'
          nic = vm.network_adapters.new
          compute.each do |k, v|
            nic.send(:"#{k}=", v.presence)
          end
          nic.mac ||= interface[:mac].presence
          nic.save
        end
      end
    end

    def validate_volumes(attr)
      volumes = nested_attributes_for :volumes, attr[:volumes_attributes]
      volumes.reject! { |vol| vol[:_delete] == '1' }
      # logger.debug "Validate Volume #{volumes.inspect}"
      volumes.each do |vol|
        raise Foreman::Exception, 'Volume lacks name' if vol[:basename].blank?
        raise Foreman::Exception, 'Volume name should not include a file extension' if vol[:basename] =~ /\.vhd[sx]?$/
        raise Foreman::Exception, 'Volume lacks size' unless vol[:size_bytes].to_i.positive?
      end
      return unless volumes.group_by { |vol| vol[:basename].downcase }.any? { |_k, v| v.many? }

      raise Foreman::Exception, 'Volume names need to be unique'
    end

    def create_volumes(vm, attr)
      volumes = nested_attributes_for :volumes, attr[:volumes_attributes]
      logger.debug "Creating volumes with: #{volumes}"
      volumes.each do |vol|
        vhd = vm.vhds.create basename: vol[:basename], size: vol[:size_bytes].to_i
        vm.hard_drives.create vhd: vhd
      end
    end

    def update_volumes(vm, attr)
      volumes = nested_attributes_for :volumes, attr[:volumes_attributes]
      logger.debug "Updating volumes with: #{volumes}"
      volumes.each do |volume|
        if volume[:id].present?
          hd = vm.hard_drives.get volume[:id]
          if volume[:_delete] == '1'
            hd.destroy(underlying: true)
          else
            vhd = hd.vhd
            vhd.size = volume[:size_bytes].to_i
            vhd.save if vhd.dirty?
          end
        elsif volume[:_delete] != '1'
          vhd = vm.vhds.create basename: volume[:basename], size: volume[:size_bytes].to_i
          vm.hard_drives.create path: vhd.path
        end
      end
    end
  end
end
