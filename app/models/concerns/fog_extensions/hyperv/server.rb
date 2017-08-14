module FogExtensions
  module Hyperv
    module Server
      extend ActiveSupport::Concern
      include ActionView::Helpers::NumberHelper

      attr_accessor :no_vhd, :new_vhd_path, :new_vhd_size_bytes

      def to_s
        name
      end

      def mac(m = mac_addresses.first)
        "#{m[0, 2]}:#{m[2, 2]}:#{m[4, 2]}:#{m[6, 2]}:#{m[8, 2]}:#{m[10, 2]}"
      end

      def clean_mac_addresses
        network_adapters.map { |n| mac(n.mac_address) }
      end

      def memory
        memory_startup
      end

      def memory_mb
        (memory_startup || 0) / 1024 / 1024
      end

      def memory_mb=(mem)
        memory_startup = (mem.to_i * 1024 * 1024)
      end

      def reset
        restart
      end

      def vm_description
        format(_('%{cpus} CPUs and %{ram} memory'), :cpus => processor_count, :ram => number_to_human_size(memory))
      end

      def select_nic(fog_nics, _nic)
        # TODO?
        fog_nics[0]
      end

      def method_missing(name, *args)
        puts "Missing method; #{name}(#{args.join ', '})"
      end
    end
  end
end
