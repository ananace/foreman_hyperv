module FogExtensions
  module Hyperv
    module Vhd
      extend ActiveSupport::Concern
      include ActionView::Helpers::NumberHelper

      def id
        identity
      end
    end
  end
end
