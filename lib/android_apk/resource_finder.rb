# frozen_string_literal: true

class AndroidApk
  module ResourceFinder
    # @attribute delegatee
    #   @return [#resolve_icons_in_arsc]
    class << self
      attr_accessor :delegatee
      self.delegatee = Aapt.new

      # @param apk_filepath [String] apk file path
      # @param default_icon_path [String, NilClass]
      # @return [Hash] keys are dpi human readable names, values are png file paths that are relative
      def resolve_icons_in_arsc(apk_filepath:, default_icon_path:)
        return {} if default_icon_path.nil? || default_icon_path.empty?

        delegatee.resolve_icons_in_arsc(apk_filepath: apk_filepath, default_icon_path: default_icon_path) or return {}
      end
    end
  end
end
