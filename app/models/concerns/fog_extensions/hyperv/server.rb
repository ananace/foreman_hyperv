module FogExtensions
  module Hyperv
    module Server
      extend ActiveSupport::Concern
      include ActionView::Helpers::NumberHelper

      attr_accessor :start

      def to_s
        name
      end

      def folder_name
        name.gsub(/[^0-9A-Za-z.\-]/, '_')
      end

      def mac(m = mac_addresses.first)
        "#{m[0, 2]}:#{m[2, 2]}:#{m[4, 2]}:#{m[6, 2]}:#{m[8, 2]}:#{m[10, 2]}"
      end

      def clean_mac_addresses
        network_adapters.map { |n| mac(n.mac_address) }
      end

      def interfaces
        network_adapters
      end

      def volumes
        vhds
      end

      def interfaces_attributes=(_attributes); end

      def volumes_attributes=(_attributes); end

      def reset
        restart(force: true)
      end

      def stop
        requires :name, :computer_name
        service.stop_vm options.merge(
          name: name,
          computer_name: computer_name,
          force: true
        )
      end

      def vm_description
        format(_('%{cpus} CPUs and %{ram} memory'), :cpus => processor_count, :ram => number_to_human_size(memory_startup))
      end

      def select_nic(fog_nics, nic)
        nic_attrs = nic.compute_attributes
        puts "select_nic(#{fog_nics}, #{nic}[#{nic_attrs}])"
        match =   fog_nics.detect { |fn| fn.name == nic_attrs['name'] } # Check the name
        match ||= fog_nics.detect { |fn| fn.switch_name == nic_attrs['network'] } # Fall back to any on the same switch
        match
      end

      def method_missing(name, *args)
        puts "[VM] Missing method; #{name}(#{args.join ', '})"
      end
    end
  end
end
