# frozen_string_literal: true

module AndroidApk::Config
  # @type [Boolean]
  attr_accessor :strict
  self.strict = true

  attr_reader :bundletool_path

  attr_accessor :aapt_path, :apksigner_path

  # @type [String, NilClass]
  def bundletool_path=(bundletool_path)
    if bundletool_path&.end_with?(".jar")
      @bundletool_path = "java -jar #{bundletool_path}"
    else
      @bundletool_path = bundletool_path
    end
  end
end
