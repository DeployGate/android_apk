# frozen_string_literal: true

class AndroidApk
  module Aapt2
    class ResourceFinder
      class << self
        # @see AndroidApk::ResourceFinder#resolve_icons_in_arsc
        # @param apk_filepath [String] a path to apk_filepath
        # @param default_icon_path [String] the path to the default icon in the apk
        def resolve_icons_in_arsc(apk_filepath:, default_icon_path:)
          return {} if default_icon_path.nil? || default_icon_path.empty?

          stdout = dump_resource_values(apk_filepath: apk_filepath) or return {}

          lines = stdout.scrub.split("\n")

          # Find the resource address line by the real resource path in the apk file.
          #   xxx...
          #     resource <address> <default_resource_name> (l blocks)
          #       (densityA) (file) "<A's icon path>" type=...
          #       (densityB) (file) "<B's icon path>" type=...
          #       (densityC) (file) "<C == default_icon_path>" type=...
          #       (densityD) (file) "<D's icon path>" type=...
          #       (densityE) (file) "<E's icon path>" type=...
          #     resource ... <another_resource_name>...
          pivot_index = lines.index { |line| line.index(default_icon_path) && line.index("type=") } or return {}

          config_hash = {}

          collect_in_section(lines: lines, pivot_index: pivot_index) do |dpi, path|
            config_hash[dpi] = path
          end

          config_hash
        end

        def collect_in_section(lines:, pivot_index:, &block)
          # 1. step back until meeting a different block.
          #   capture <default_icon_path>, <B's icon path>, <C's icon path>
          #   hit `resource ... <default_resource_name> ...` block
          # 2. go back to the pivot
          # 3. step forward until meeting a different block.
          #   capture <D's icon path>, <E's icon path>
          #   hit `resource ... <another_resource_name> ...` block
          # 4. done!

          expected_indent_level = lines[pivot_index][/\A\s+/].size

          cursor_index = pivot_index
          direction = :up

          while cursor_index >= 0 && cursor_index < lines.size
            # if the indent level has changed, process step 2 or 4
            if lines[cursor_index][/\A\s+/].size != expected_indent_level
              # go to step.4!
              break if direction == :down

              direction = :down
              cursor_index = pivot_index + 1 # step2 and step forward
            end

            captures = lines[cursor_index]&.lstrip&.match(/\((?'dpi'.*)\)\s+\(file\)\s+(?'path'\S+)/)&.named_captures || {}

            dpi = captures["dpi"]
            path = captures["path"]

            break if dpi.nil? || path.nil? # unexpected.

            dpi = dpi.empty? ? ::AndroidApk::DEFAULT_RESOURCE_CONFIG : dpi # reassign

            block.call(dpi, path)

            if direction == :up
              # step back
              cursor_index -= 1
            else
              # step forward
              cursor_index += 1
            end
          end
        end

        def dump_resource_values(apk_filepath:)
          stdout, _, status = Open3.capture3("aapt2", "dump", "resources", apk_filepath)
          # we just need only drawables/mipmaps, and they are utf-8(ascii) friendly.
          stdout if status.success?
        end
      end
    end
  end
end
