# frozen_string_literal: true

class AndroidApk
  module ResourceFinder
    class << self
      # @param apk_filepath [String] apk file path
      # @param default_icon_path [String, NilClass]
      # @return [Hash] keys are dpi human readable names, values are png file paths that are relative
      def resolve_icons_in_arsc(apk_filepath:, default_icon_path:)
        return {} if default_icon_path.nil? || default_icon_path.empty?

        stdout = dump_resource_values(apk_filepath: apk_filepath) or return {}

        lines = stdout.scrub.split("\n")

        # Find the resource address line by the real resource path in the apk file.
        #
        #     resource ... <resource_name>: ... (l blocks)
        #       ... "<default_icon_path>"
        value_index = lines.index { |line| line.index(default_icon_path) } or return {}
        resource_find_index = value_index
        resource_name = ""
        while resource_find_index >= 0
          line = lines[resource_find_index]
          resource_find_index -= 1

          if line.index("resource ")
            resource_name = line.split(" ")[2] # e.g. mipmap/ic_launcher
            break
          end
        end
        return {} if resource_name == ""

        start_index = lines.index { |line| line.index(resource_name) }

        config_hash = {}

        lines = lines.drop(start_index + 1)

        # A target to find values is only one *type* block.
        #
        # type <number> configCount=<m> entryCount=<l> (N blocks)
        #   resource ... <resource_name>: ... (l blocks)
        #     ... "<file path>"
        index = 0

        while index < lines.size

          line = lines[index]
          index += 1

          break if line.index("resource ")
          break if line.index("type ")

          config = line.match(/\((?'dpi'.+)\)\s+\(.+\)/)&.named_captures&.dig("dpi")
          config = "(default)" unless config

          png_file_path = line.split(" ")[2]
          config_hash[config] = png_file_path
        end

        config_hash
      end

      def dump_resource_values(apk_filepath:)
        stdout, _, status = Open3.capture3("aapt2", "dump", "resources", apk_filepath)
        # we just need only drawables/mipmaps, and they are utf-8(ascii) friendly.
        stdout if status.success?
      end
    end
  end
end
