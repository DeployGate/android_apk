# frozen_string_literal: true

class AndroidApk::Config
  # @type [Boolean]
  attr_accessor :strict

  # @type [String, NilClass]
  def bundletool_path=(bundletool_path)
    AndroidApk::Bundletool.bundletool_path = bundletool_path
  end

  # @type [String, NilClass]
  def aapt_path=(aapt_path)
    AndroidApk::Aapt.aapt_path = aapt_path
  end
end
