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
      super options
      client.valid?
    rescue Fog::Hyperv::Errors::ServiceError
      false
    end

    def provided_attributes
      super.merge(mac: :mac)
    end

    # TODO
    def max_cpu_count
      24
    end

    def max_memory
      32.gigabytes
    end

    def associated_host(vm)
      associate_by('mac', vm.clean_mac_addresses)
    end

    def new_vm(attr = {})
      vm = super
      interfaces = nested_attributes_for :interfaces, attr[:interfaces_attributes]
      interfaces.map{ |i| vm.interfaces << new_interface(i)}
      volumes = nested_attributes_for :volumes, attr[:volumes_attributes]
      volumes.map { |v| vm.volumes << new_volume(v) }
      vm
    end

    def new_interface(attr = {})
      Fog::Compute::Hyperv::NetworkAdapter.new(attr)
    end

    def new_volume(attr = {})
      Fog::Compute::Hyperv::Vhd.new(attr)
    end

    def stop_vm(uuid)
      find_vm_by_uuid(uuid).stop force: true
    end

    def create_vm(args = {})
      args = vm_instance_defaults.merge(args.to_hash.deep_symbolize_keys)
      puts "Creating a VM with arguments; #{args}"
      pre_create = {
        boot_device: 'NetworkAdapter',
        generation: args[:generation].to_i,
        memory_startup: args[:memory_startup].presence,
        name: args[:name],
        no_vhd: true
      }

      vm = client.servers.create pre_create

      post_save = {
        dynamic_memory_enabled: ActiveRecord::Type::Boolean.new.type_cast_from_user(args[:dynamic_memory_enabled]),
        notes: args[:notes].presence,
        processor_count: args[:processor_count].to_i
      }
      post_save.each do |k, v|
        vm.send("#{k}=".to_sym, v)
      end

      vm.save if vm.dirty?

      create_interfaces(vm, args[:interfaces_attributes])
      create_volumes(vm, args[:volumes_attributes])

      vm.start unless ActiveRecord::Type::Boolean.new.type_cast_from_user args[:start]
      vm
    end

    def save_vm(uuid, attr)
      vm = find_vm_by_uuid(uuid)
      attr.each do |k, v|
        vm.send("#{k}=".to_sym, v)
      end
      update_interfaces(vm, attr[:interfaces_attributes])
      update_volumes(vm, attr[:volumes_attributes])
      vm.save if vm.dirty?
      vm
    end

    def destroy_vm(uuid)
      vm = find_vm_by_uuid(uuid)
      vm.stop turn_off: true
      vm.hard_drives.each do |hd|
        hd.vhd.destroy if hd.path
      end
      vm.destroy
    rescue ActiveRecord::RecordNotFound
      # if the VM does not exists, we don't really care.
      true
    end

    def new_interface(attr = {})
      puts "new_interface(#{attr})"
      client.network_adapter.new attr
    end

    def new_volume(attr = {})
      puts "new_volume(#{attr})"
      client.vhds.new attr
    end

    def new_cdrom(attr = {})
      puts "new_cdrom(#{attr})"
      client.dvd_drives.new attr
    end

    def editable_network_interfaces?
      true
    end

    def networks
      switches.map { |sw| sw.name }
    end

    def switches
      client.switches.all _quick_query: true
    end

    def supports_update?
      true
    end

    protected

    def client
      @client ||= Fog::Compute.new(
        provider: :HyperV,
        hyperv_endpoint: url,
        hyperv_username: user,
        hyperv_password: password,
        hyperv_debug: true
      )
    end

    def create_interfaces(vm, attrs)
      interfaces = nested_attributes_for :interfaces, attrs
      puts "Building interfaces with: #{interfaces}"
      interfaces.each_with_index do |iface, i|
        nic = vm.network_adapters[i] || vm.network_adapters.new
        nic.switch_name = iface[:switch_name]
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
      puts "Building volumes with: #{volumes}"
      volumes.each do |vol|
        vhd = vm.vhds.create path: vol[:path], size: vol[:size]
        vm.hard_drives.create path: vhd.path
      end
      vm.hard_drives.reload
    end

    def update_interfaces(vm, attrs)
      interfaces = nested_attributes_for :interfaces, attrs
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
      volumes.each do |volume|
        if volume[:_delete] == '1' && volume[:id].present?
          hd = vm.hard_drives.get(path: volume[:path])
          hd.vhd.destroy
          hd.destroy
        end
        vm.hard_drives.create(path: volume[:path], size: volume[:size]) if volume[:id].blank?
      end
    end
  end
end
