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

    def associated_host(vm)
      associate_by('mac', vm.clean_mac_addresses)
    end

    def create_vm(args = {})
      pre_create = {
        boot_device: 'NetworkAdapter',
        dynamic_memory_enabled: ActiveRecord::Type::Boolean.new.type_cast_from_user(args[:dynamic_memory_enabled]),
        generation: args[:generation].to_i,
        memory_startup: args[:memory_startup].presence,
        name: args[:name],
        new_vhd_path: args[:new_vhd_path].presence,
        new_vhd_size_bytes: args[:new_vhd_size_bytes].presence,
        no_vhd: ActiveRecord::Type::Boolean.new.type_cast_from_user(args[:no_vhd]),
        switch_name: args[:switch_name].presence
      }

      # TODO;
      # Create with no VHD, no switch
      # Use volume + interface data to add after creation of VM

      vm = client.servers.create pre_create

      post_save = {
        dynamic_memory_enabled: ActiveRecord::Type::Boolean.new.type_cast_from_user(args[:dynamic_memory_enabled]),
        notes: args[:notes].presence,
        processor_count: args[:processor_count].to_i,
      }
      post_save.each do |k, v|
        vm.send("#{k}=".to_sym, v)
      end

      vm.save if vm.dirty?

      # Populate the MAC address
      vm.start
      vm.stop turn_off: true
      
      vm.network_adapters.each do |nic|
        nic.dynamic_mac_address_enabled = false
        nic.save
      end
      
      vm.start unless ActiveRecord::Type::Boolean.new.type_cast_from_user args[:start]
      vm
    rescue
      vm.destroy if vm.id
    end

    def save_vm(uuid, attr)
      vm = find_vm_by_uuid(uuid)
      attr.each do |k, v|
        vm.send("#{k}=".to_sym, v)
      end
      vm.save if vm.dirty?
      vm
    end

    def destroy_vm(uuid)
      vm = find_vm_by_uuid(uuid)
      vm.stop turn_off: true
      vm.hard_drives.each do |hd|
        # TODO; Be cleaner about this?
        client.remove_item path: hd.path
      end
      vm.destroy
    rescue ActiveRecord::RecordNotFound
      # if the VM does not exists, we don't really care.
      true
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
  end
end
