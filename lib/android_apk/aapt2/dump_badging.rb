# frozen_string_literal: true

class AndroidApk
  module Aapt2
    class DumpBadging
      # @!attribute [r] raw_result_lines
      #   @return [Array<String>] Raw outputs of aapt2 dump badging
      class Result
        attr_reader :raw_result_lines

        def initialize(raw_result_lines:, parsed_variables:)
          @raw_result_lines = raw_result_lines
          @parsed_variables = parsed_variables
        end

        # @return [String, NilClass] Return a value which is defined in AndroidManifest.xml. Could be nil.
        def label
          @parsed_variables["application-label"]
        end

        # @return [String] Return a relative path of this apk's icon. This is the real filepath in the apk but not resource-friendly path.
        def default_icon_path
          @parsed_variables["application"]["icon"]
        end

        # @return [String] an application's package name which is defined in AndroidManifest
        def package_name
          @parsed_variables["package"]["name"]
        end

        # @return [String] an application's version code which is defined in AndroidManifest
        def version_code
          @parsed_variables["package"]["versionCode"]
        end

        # FIXME: don't return empty but return nil as it is cuz it's valid.
        # @return [String] an application's version name which is defined in AndroidManifest or empty
        def version_name
          @parsed_variables["package"]["versionName"] || ""
        end

        # @return [String, NilClass] an application's min sdk version. The format is an integer string which is defined in AndroidManifest.xml. Legacy apk may return nil.
        def min_sdk_version
          # Return value with "sdkVersion" before build-tools 34.0.0, and "minSdkVersion" after build-tools 35.0.0
          @parsed_variables["minSdkVersion"] || @parsed_variables["sdkVersion"]
        end

        # @return [String, NilClass] an application's target sdk version. The format is an integer string which is defined in AndroidManifest.xml. Legacy apk may return nil.
        def target_sdk_version
          @parsed_variables["targetSdkVersion"]
        end

        # @return [Boolean] Check whether or not this apk is a test mode. Return true if an apk is a test apk
        def test_only
          @parsed_variables.key?("testOnly='-1'")
        end

        alias test_only? test_only

        # @return [Hash<{String => String}>] A hash whose keys are names of meta-data and values are of them.
        def meta_data
          return @meta_data if defined?(@meta_data)

          @meta_data = (@parsed_variables["meta-data"] || []).each_with_object({}) do |h, acc|
            acc[h["name"]] = h["value"]
          end
        end

        # @return [Hash] an application's labels a.k.a application name in available resources.
        def labels
          @parsed_variables["labels"]
        end

        # @return [Hash] an application's relative icon paths grouped by densities
        # @deprecated no longer used
        def icons
          @parsed_variables["icons"]
        end
      end

      MULTIPLE_ELEMENTS_TAG_NAMES = %w(
        meta-data
      ).freeze
      BOOLEAN_ELEMENT_TAG_NAMES = %w(
        testOnly='-1'
        application-debuggable
      ).freeze
      SINGLE_VALUE_ELEMENT_TAG_NAMES = %w(
        application
        application-label
        package
        sdkVersion
        minSdkVersion
        targetSdkVersion
      ).freeze

      NOT_ALLOW_DUPLICATE_TAG_NAMES = %w(
        application
        sdkVersion
        minSdkVersion
        targetSdkVersion
      ).freeze

      # @return [String]
      def self.dump_badging(apk_filepath:)
        stdout, stderr, status = Open3.capture3("aapt2", "dump", "badging", "--include-meta-data", apk_filepath)

        if status.success?
          stdout
        else
          if stderr.index(/ERROR:?\s/i) # : is never required because it's mixed.
            if stderr.include?("failed opening zip")
              raise InvalidApkError, "This apk file is an invalid zip-format or contains no AndroidManifest.xml"
            elsif stderr.include?("failed to parse binary AndroidManifest.xml")
              raise InvalidApkError, "AndroidManifest.xml seems to be invalid and not decode-able."
            else
              # *normally* failed. The output of aapt2 dump is helpful.
              # ref: https://cs.android.com/android/platform/superproject/+/master:frameworks/base/tools/aapt/Command.cpp;l=860?q=%22dump%20failed%22%20aapt
              raise Aapt2Error.new(message: "This apk file cannot be parsed using 'aapt2 dump badging --include-meta-data'", stdout: stdout, stderr: stderr)
            end
          else
            # unexpectedly failed. This may happen due to the running environment.
            raise Aapt2Error.new(message: "'aapt2 dump badging --include-meta-data' failed due to an unexpected error.", stdout: stdout, stderr: stderr)
          end
        end
      end

      # @param apk_filepath [String] a path to apk_filepath
      def initialize(apk_filepath:)
        @apk_filepath = apk_filepath
      end

      # Parse output of aapt2 command to Hash format
      #
      # @return [::AndroidApk::Aapt2::DumpBadging::Result]
      def parse
        return @parse if defined?(@parse)

        raw_result_lines = self.class.dump_badging(apk_filepath: @apk_filepath).scrub.split("\n")

        vars = {
          "labels" => {},
          "icons" => {},
          "meta-data" => []
        }

        raw_result_lines.each do |line|
          key, value = parse_line(line)

          if !(m = key.match(/\Aapplication-icon-(\d+)\z/)).nil?
            vars["icons"][m[1].to_i] = value unless value.nil?
          elsif !(m = key.match(/\Aapplication-label-(\S+)\z/)).nil?
            vars["labels"][m[1]] = value unless value.nil?
          else
            # noinspection RubyCaseWithoutElseBlockInspection
            case key
            when *BOOLEAN_ELEMENT_TAG_NAMES
              vars[key] = true
            when *MULTIPLE_ELEMENTS_TAG_NAMES
              if value.kind_of?(Hash)
                vars[key].push(value)
              else
                vars[key].push(*value)
              end
            when *SINGLE_VALUE_ELEMENT_TAG_NAMES
              reject_illegal_duplicated_key!(key) if vars.key?(key)

              vars[key] = value
            end
          end
        end

        @parse = Result.new(raw_result_lines: raw_result_lines, parsed_variables: vars)
      end

      # workaround for https://code.google.com/p/android/issues/detail?id=160847
      private def parse_values_workaround(str)
        return nil if str.nil?

        str.scan(/^'(.+)'$/).map { |v| v[0].gsub("\\'", "'") }
      end

      # Parse values of aapt output
      #
      # @param [String, nil] str a values string of aapt output.
      # @return [Array, Hash, nil] return nil if (see str) is nil. Otherwise the parsed array will be returned.
      private def parse_values(str)
        return nil if str.nil?

        if str.index("='")
          # key-value hash
          vars = str.scan(/(\S+)='((?:\\'|[^'])*)'/).to_h
          vars.each_value { |v| v.gsub("\\'", "'") }
        else
          # values array
          vars = str.scan(/'((?:\\'|[^'])*)'/).map { |v| v[0].gsub("\\'", "'") }
        end
        return vars
      end

      # Parse output of a line of aapt command like `key: values`
      #
      # @param [String] line a line of aapt command.
      # @return [[String, Hash]] return nil if (see line) is nil. Otherwise the parsed hash will be returned.
      private def parse_line(line)
        key, values = line.split(":", 2)

        values =
          if key.start_with?("application-label")
            parse_values_workaround(values)
          else
            parse_values(values)
          end

        if values.nil? || values.kind_of?(Hash) || values.length > 1
          [key, values]
        else
          [key, values[0]]
        end
      end

      # @param [String] key a key of AndroidManifest.xml
      # @raise [InvalidApkError] if a key is found in (see NOT_ALLOW_DUPLICATE_TAG_NAMES)
      private def reject_illegal_duplicated_key!(key)
        raise InvalidApkError, "duplicates of #{key} tag in AndroidManifest.xml are invalid." if NOT_ALLOW_DUPLICATE_TAG_NAMES.include?(key)
      end
    end
  end
end
