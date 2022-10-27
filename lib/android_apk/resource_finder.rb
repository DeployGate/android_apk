# frozen_string_literal: true

class AndroidApk
  class ResourceFinder
    class << self
      # @param apk_filepath [String] apk file path
      # @param default_icon_path [String, NilClass]
      # @return [Hash] keys are dpi human readable names, values are png file paths that are relative
      def decode_resource_table(apk_filepath:, default_icon_path:)
        aapt2 = ::AndroidApk::Aapt2::DumpResources.new(apk_filepath: apk_filepath)
        aapt2.parse_icons(default_icon_path: default_icon_path)
      end
    end
  end
end
