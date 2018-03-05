module ForemanHyperv
  class Hyperv < ::ComputeResource
    validates :url, :user, :password, presence: true

    def capabilities
      [:build]
    end

    def self.provider_friendly_name
      'Hyper-V'
    end

    def self.model_name
      ComputeResource.model_name
    end

    def test_connection(options = {})
      super
      client.valid?
    rescue Fog::Hyperv::Errors::ServiceError, ArgumentError, WinRM::WinRMAuthorizationError => e
      errors[:base] << e.message
    end

    def provided_attributes
      super.merge(mac: :mac)
    end

    # TODO
    def max_cpu_count
      hypervisor.logical_processor_count
    end

    def max_memory
      hypervisor.memory_capacity
    end

    def associated_host(vm)
      associate_by('mac', vm.clean_mac_addresses)
    end

    def new_vm(attr = {})
      vm = super
      interfaces = nested_attributes_for :interfaces, attr[:interfaces_attributes]
      interfaces.map { |i| vm.interfaces << new_interface(i) }
      volumes = nested_attributes_for :volumes, attr[:volumes_attributes]
      volumes.map { |v| vm.volumes << new_volume(v) }
      vm
    end

    def stop_vm(uuid)
      find_vm_by_uuid(uuid).stop force: true
    end

    def create_vm(args = {})
      args = vm_instance_defaults.merge(args.to_hash.deep_symbolize_keys)
      client.logger.debug "Creating a VM with arguments; #{args}"

      args[:computer_name] = args[:computer_name].presence || '.'

      pre_create = {
        boot_device: 'NetworkAdapter',
        computer_name: args[:computer_name],
        generation: args[:generation].to_i,
        memory_startup: args[:memory_startup].presence.to_i,
        name: args[:name],
        no_vhd: true
      }

      vm = client.servers.create pre_create

      post_save = {
        dynamic_memory_enabled: Foreman::Cast.to_bool(args[:dynamic_memory_enabled]),
        memory_minimum: args[:memory_minimum].presence.to_i,
        memory_maximum: args[:memory_maximum].presence.to_i,
        notes: args[:notes].presence,
        processor_count: args[:processor_count].to_i
      }
      post_save.each do |k, v|
        vm.send("#{k}=".to_sym, v)
      end

      vm.save if vm.dirty?

      if vm.generation == 2 && args[:secure_boot_enabled].present?
        f = vm.firmware
        f.secure_boot = Foreman::Cast.to_bool(args[:secure_boot_enabled]) ? :On : :Off
        f.save if f.dirty?
      end

      create_interfaces(vm, args[:interfaces_attributes])
      create_volumes(vm, args[:volumes_attributes])

      vm.set_vlan(args[:vlan].to_i) if args[:vlan].presence && vm.respond_to?(:set_vlan)

      vm
    rescue StandardError => e
      vm.stop turn_off: true

      raise e
    end

    def save_vm(uuid, attr)
      vm = find_vm_by_uuid(uuid)
      client.logger.debug "Saving a VM with arguments; #{attr}"
      attr.each do |k, v|
        vm.send("#{k}=".to_sym, v) if vm.respond_to?("#{k}=".to_sym)
      end

      if vm.generation == 2 && attr[:secure_boot_enabled].present?
        f = vm.firmware
        f.secure_boot = Foreman::Cast.to_bool(attr[:secure_boot_enabled]) ? :On : :Off
        f.save if f.dirty?
      end

      update_interfaces(vm, attr[:interfaces_attributes])
      update_volumes(vm, attr[:volumes_attributes])

      vm.save if vm.dirty?
      vm
    end

    def destroy_vm(uuid)
      vm = find_vm_by_uuid(uuid)
      vm.stop force: true if vm.ready?
      vm.hard_drives.each do |hd|
        hd.vhd.destroy if hd.path
      end
      # TODO: Remove the empty VM folder
      vm.destroy
    rescue ActiveRecord::RecordNotFound, Fog::Errors::NotFound
      # if the VM does not exists, we don't really care.
      true
    end

    def new_interface(attr = {})
      client.network_adapters.new attr
    end

    def new_volume(attr = {})
      client.vhds.new attr
    end

    def new_cdrom(attr = {})
      client.dvd_drives.new attr
    end

    def editable_network_interfaces?
      true
    end

    def switches
      client.switches.all # _quick_query: true
    end

    def supports_update?
      true
    end

    def available_hypervisors
      client.hosts
    end
    alias hosts available_hypervisors

    def clusters
      if client.respond_to? :supports_clusters?
        return [] unless client.supports_clusters?
      end
      client.clusters rescue []
    end

    def hypervisor
      client.hosts.first
    end

    delegate :servers, to: :client

    protected

    def client
      @client ||= Fog::Compute.new(
        provider: :HyperV,
        hyperv_endpoint: url,
        hyperv_username: user,
        hyperv_password: password
      )
    end

    def vm_instance_defaults
      super.merge(
        generation:      1,
        memory_startup:  512.megabytes,
        processor_count: 1,
        boot_device:     'NetworkAdapter'
      )
    end

    def create_interfaces(vm, attrs)
      vm.network_adapters.each(&:destroy)

      interfaces = nested_attributes_for :interfaces, attrs
      client.logger.debug "Building interfaces with: #{interfaces}"
      interfaces.each do |iface|
        nic = vm.network_adapters.new name: iface[:name], switch_name: iface[:network]
        if iface[:mac]
          nic.mac = iface[:mac]
          nic.dynamic_mac_address_enabled = false
        end
        nic.save
      end

      # Populate the MAC addresses
      vm.start
      vm.stop turn_off: true

      vm.network_adapters.reload
      vm.network_adapters.each do |nic|
        nic.dynamic_mac_address_enabled = false
        nic.save if nic.dirty?
      end
    end

    def create_volumes(vm, attrs)
      volumes = nested_attributes_for :volumes, attrs
      client.logger.debug "Building volumes with: #{volumes}"
      volumes.each do |vol|
        vhd = vm.vhds.create path: vm.folder_name + '\\' + vol[:path], size: vol[:size]
        vm.hard_drives.create path: vhd.path
      end
      vm.hard_drives.reload
    end

    def update_interfaces(vm, attrs)
      interfaces = nested_attributes_for :interfaces, attrs
      client.logger.debug "Updating interfaces with: #{interfaces}"
      interfaces.each do |interface|
        if interface[:id].blank? && interface[:_delete] != '1'
          nic = vm.network_adapters.create interface
          nic.dynamic_mac_address_enabled = false if nic.mac
          nic.save
        elsif interface[:id].present?
          nic = vm.network_adapters.find { |n| n.id == interface[:id] }
          if interface[:_delete] == '1'
            nic.delete
          else
            interface.each do |k, v|
              nic.send("#{k}=".to_sym, v)
            end
            nic.save if nic.dirty?
          end
        end
      end
    end

    def update_volumes(vm, attrs)
      volumes = nested_attributes_for :volumes, attrs
      client.logger.debug "Updating volumes with: #{volumes}"
      volumes.each do |volume|
        if volume[:_delete] == '1' && volume[:id].present?
          hd = vm.hard_drives.find { |h| h.id == volume[:id] }
          hd.vhd.destroy
          hd.destroy
        end
        vm.hard_drives.create(path: volume[:path], size: volume[:size]) if volume[:id].blank? && volume[:_delete] != '1'
      end
    end
  end
end
