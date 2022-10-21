# frozen_string_literal: true

class AndroidApk
  class ResourceFinder
    # @param delegatee [#resolve_icons_in_arsc]
    def initialize(delegatee:)
      raise "delegatee must not be nil" if delegatee.nil? || !delegatee.respond_to?(:resolve_icons_in_arsc)

      @delegatee = delegatee
    end

    # @param apk_filepath [String] apk file path
    # @param default_icon_path [String, NilClass]
    # @return [Hash] keys are dpi human readable names, values are png file paths that are relative
    def resolve_icons_in_arsc(apk_filepath:, default_icon_path:)
      @delegatee.resolve_icons_in_arsc(apk_filepath: apk_filepath, default_icon_path: default_icon_path) or {}
    end
  end
end
