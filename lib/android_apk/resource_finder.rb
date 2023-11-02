# frozen_string_literal: true

class AndroidApk
  module ResourceFinder
    class << self
      # @param apk_filepath [String] apk file path
      # @param default_icon_path [String, NilClass]
      # @return [Hash] keys are dpi human readable names, values are png file paths that are relative
      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def resolve_icons_in_arsc(apk_filepath:, default_icon_path:)
        return {} if default_icon_path.nil? || default_icon_path.empty?

        stdout = dump_resource_values(apk_filepath: apk_filepath) or return {}

        lines = stdout.scrub.split("\n")

        # Find the resource address line by the real resource path in the apk file.
        #
        #     resource ... <resource_name>: ... (l blocks)
        #       ... "<default_icon_path>"
        value_index = lines.index { |line| line.index(default_icon_path) } or return {}

        # resource_name never contain ':'
        resource_name = lines[value_index - 1].split(":")[1] or return {} # e.g. mipmap/ic_launcher
        resource_name = ":#{resource_name}:" # to specify only <resource name>. The original value cannot avoid any resources that start with <resource_name>

        start_index = lines.index { |line| line.index("spec resource ") && line.index(resource_name) }

        config_hash = {}

        lines = lines.drop(start_index + 1)

        # A target to find values is only one *type* block.
        #
        # type <number> configCount=<m> entryCount=<l> (N blocks)
        #   spec resource ... (l lines)
        #   config <config_name>: (m blocks)
        #     resource ... <resource_name>: ... (l blocks)
        #       ... "<file path>"

        # lines that start with "spec" are already rejected
        index = 0

        while index < lines.size

          line = lines[index]
          index += 1

          break if line.index("type ")

          # drop until a config block will be found
          next unless (config = line.match(/config\s+(?'dpi'.+):/)&.named_captures&.dig("dpi"))
          next unless line.index("(default)") || line.index("dpi")

          while index < lines.size
            line = lines[index]

            break if line.index("config ")

            index += 1

            # drop until a line contains <resource_name>
            next unless line.index(resource_name)

            # Next line may contain the filepath and never contain a config block header
            line = lines[index]
            index += 1

            # if path node is present, it never nil
            if (png_file_path = line.match(/\(string8\) "(?'path'.+)"/)&.named_captures&.dig("path")).nil?
              ::AndroidApk.logger.warn("#{line} does not contain a valid filepath")
            else
              config_hash[config] = png_file_path
            end

            break
          end
        end

        config_hash
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def dump_resource_values(apk_filepath:)
        stdout, _, status = Open3.capture3("aapt", "dump", "--values", "resources", apk_filepath)
        # we just need only drawables/mipmaps, and they are utf-8(ascii) friendly.
        stdout if status.success?
      end
    end
  end
end
