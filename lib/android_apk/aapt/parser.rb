module AndroidApk::Aapt
  class Parser

    # Parse output of aapt command to Hash format
    #
    # @param [String] raw raw output of aapt command. this may be multi lines.
    # @return [AndroidApk::Aapt::ParsedResult]
    # @raise [AndroidApk::Aapt::ParseError]
    def self.parse(raw)
      vars = _parse(raw)

      AndroidApk::Aapt::ParsedResult.new.tap do |r|
        r.application_label = vars["application-label"]
        r.application_icon = vars["application"]["icon"]
        r.test_only = vars.key?("testOnly='-1'")

        # package

        r.package_name = vars["package"]["name"]
        r.version_code = vars["package"]["versionCode"]
        r.version_name = vars["package"]["versionName"]

        # platforms
        r.min_sdk_version = vars["sdkVersion"].kind_of?(Array) ? vars["sdkVersion"].min : vars["sdkVersion"]
        r.target_sdk_version = vars["targetSdkVersion"].kind_of?(Array) ? vars["targetSdkVersion"].min : vars["targetSdkVersion"]

        # icons and labels
        r.icons = {}
        r.labels = {}
        vars.each_key do |k|
          r.icons[Regexp.last_match(1).to_i] = vars[k] if k =~ /^application-icon-(\d+)$/
          r.labels[Regexp.last_match(1)] = vars[k] if k =~ /^application-label-(\S+)$/
        end
      end
    rescue
      raise ::AndroidApk::Aapt::ParseError
    end

    def self._parse(raw)
      vars = {}
      raw.split("\n").each do |line|
        key, value = _parse_line(line)
        next if key.nil?

        if vars.key?(key)
          reject_illegal_duplicated_key!(key)

          if vars[key].kind_of?(Hash) and value.kind_of?(Hash)
            vars[key].merge(value)
          else
            vars[key] = [vars[key]] unless vars[key].kind_of?(Array)
            if value.kind_of?(Array)
              vars[key].concat(value)
            else
              vars[key].push(value)
            end
          end
        else
          vars[key] = if value.nil? || value.kind_of?(Hash)
                        value
                      else
                        value.length > 1 ? value : value[0]
                      end
        end
      end

      vars
    end

    # workaround for https://code.google.com/p/android/issues/detail?id=160847
    def self._parse_values_workaround(str)
      return nil if str.nil?

      str.scan(/^'(.+)'$/).map { |v| v[0].gsub(/\\'/, "'") }
    end

    # Parse values of aapt output
    #
    # @param [String, nil] str a values string of aapt output.
    # @return [Array, Hash, nil] return nil if (see str) is nil. Otherwise the parsed array will be returned.
    def self._parse_values(str)
      return nil if str.nil?

      if str.index("='")
        # key-value hash
        vars = Hash[str.scan(/(\S+)='((?:\\'|[^'])*)'/)]
        vars.each_value { |v| v.gsub(/\\'/, "'") }
      else
        # values array
        vars = str.scan(/'((?:\\'|[^'])*)'/).map { |v| v[0].gsub(/\\'/, "'") }
      end
      return vars
    end

    # Parse output of a line of aapt command like `key: values`
    #
    # @param [String, nil] line a line of aapt command.
    # @return [[String, Hash], nil] return nil if (see line) is nil. Otherwise the parsed hash will be returned.
    def self._parse_line(line)
      return nil if line.nil?

      info = line.split(":", 2)
      values =
          if info[0].start_with?("application-label")
            _parse_values_workaround info[1]
          else
            _parse_values info[1]
          end
      return info[0], values
    end

    # @param [String] key a key of AndroidManifest.xml
    # @raise [AndroidManifestValidateError] if a key is found in (see NOT_ALLOW_DUPLICATE_TAG_NAMES)
    def self.reject_illegal_duplicated_key!(key)
      raise DuplicatedTagError, "Duplication of #{key} tag is not allowed" if duplicated_tag?(key)
    end
  end
end