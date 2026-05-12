module FogExtensions
  module Hyperv
    module HardDrive
      extend ActiveSupport::Concern
      include ActionView::Helpers::NumberHelper

      def size_bytes=(new_size)
        raise ArgumentError, "Can't modify a physical disk" if disk

        vhd ||= Fog::Hyperv::Compute::Vhd.new unless persisted?
        vhd.size = new_size
      end

      def basename
        vhd&.basename
      end

      def basename=(new_basename)
        raise ArgumentError, "Can't modify a physical disk" if disk

        vhd ||= Fog::Hyperv::Compute::Vhd.new unless persisted?
        vhd.basename = new_basename
      end

      def compute_attributes
        attributes
          .slice(:id)
          .merge(
            {
              basename:,
              size_bytes:
            }.compact
          )
      end
    end
  end
end
