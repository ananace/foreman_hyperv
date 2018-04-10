module FogExtensions
  module Hyperv
    module NetworkAdapter
      extend ActiveSupport::Concern
      include ActionView::Helpers::NumberHelper

      def to_s
        name
      end

      def mac
        m = mac_address.downcase
        "#{m[0, 2]}:#{m[2, 2]}:#{m[4, 2]}:#{m[6, 2]}:#{m[8, 2]}:#{m[10, 2]}"
      end

      def mac=(m)
        self.mac_address = m.remove ':'
      end

      def network
        switch_name
      end

      def network=(net)
        self.switch_name = net
      end

      def type
        is_legacy
      end

      def type=(type)
        self.is_legacy = type
      end
    end
  end
end
