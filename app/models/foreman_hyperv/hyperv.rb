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
      super.merge(mac: :mac, ip: :public_ip_address)
    end

    def associated_host(vm)
      associate_by('mac', vm.clean_mac_addresses)
    end

    def create_vm(args = {})
      args[:boot_device] = :NetworkAdapter
      args[:memory_startup] = (args.delete(:memory_mb) || 0).to_i * 1024 * 1024
      args[:dynamic_memory_enabled] = ActiveRecord::Type::Boolean.new.type_cast_from_user(args.delete(:dynamic_memory_enabled) || '0')
      args[:no_vhd] = ActiveRecord::Type::Boolean.new.type_cast_from_user(args.delete(:no_vhd) || '0')

      vm = super args

      vm.attributes.merge!(
        processor_count: args[:processor_count].to_i,
      )
      vm.save
    end

    def switches
      client.switches
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
