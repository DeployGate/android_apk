module AndroidApk::Aapt
  class ParsedResult
    attr_accessor :application_label
    attr_accessor :application_icon
    attr_accessor :test_only
    attr_accessor :package_name
    attr_accessor :version_code
    attr_accessor :version_name
    attr_accessor :min_sdk_version
    attr_accessor :target_sdk_version
    attr_accessor :icons
    attr_accessor :labels
  end
end