module FogExtensions
  module Hyperv
    module Vhd
      extend ActiveSupport::Concern
      include ActionView::Helpers::NumberHelper

      def id
        identity
      end

      def method_missing(name, *args)
        puts "[VHD] Missing method; #{name}(#{args.join ', '})"
      end
    end
  end
end
