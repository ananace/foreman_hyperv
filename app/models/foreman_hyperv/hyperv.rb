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
