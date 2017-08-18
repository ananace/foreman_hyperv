module FogExtensions
  module Hyperv
    module NetworkAdapter
      extend ActiveSupport::Concern
      include ActionView::Helpers::NumberHelper

      def to_s
        name
      end

      def mac
        m = mac_address
        "#{m[0, 2]}:#{m[2, 2]}:#{m[4, 2]}:#{m[6, 2]}:#{m[8, 2]}:#{m[10, 2]}"
      end

      def mac=(m)
        mac_address = m.remove ':'
      end

      def network
        switch_name
      end

      def network=(net)
        switch_name = net
      end

      def method_missing(name, *args)
        puts "[NIC] Missing method; #{name}(#{args.join ', '})"
      end
    end
  end
end
