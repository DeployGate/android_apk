# frozen_string_literal: true

require "fileutils"
require "open3"
require "shellwords"
require "tmpdir"
require "zip"

require_relative "./android_apk/error"
require_relative "./android_apk/resource_finder"

class AndroidApk
  FALLBACK_DPI = 65_534
  ADAPTIVE_ICON_SDK = 26

  DEFAULT_RESOURCE_CONFIG = "(default)" # very special config

  # Dump result which was parsed manually
  # @return [Hash] Return a parsed result of aapt dump
  attr_accessor :results

  # Application label a.k.a application name in the default resource
  # @return [String, NilClass] Return a value which is defined in AndroidManifest.xml. Could be nil.
  attr_accessor :label

  # Application labels a.k.a application name in available resources
  # @return [Hash] Return a hash based on AndroidManifest.xml
  attr_accessor :labels

  # @deprecated no longer used
  # Application icon's path
  # @return [String] Return a relative path of this apk's icon
  attr_accessor :icon

  # @deprecated no longer used
  # Application icon paths for all densities
  # @return [Hash] Return a hash of relative paths
  attr_accessor :icons

  # Application icon paths for all densities that are human readable names
  # This value may contains anyapi-v<api_version>.
  #
  # @return [Hash] Return a hash of relative paths
  attr_accessor :icon_path_hash

  # Package name of this apk
  # @return [String] Return a value which is defined in AndroidManifest.xml
  attr_accessor :package_name

  # Version code of this apk
  # @return [String] Return a value which is defined in AndroidManifest.xml
  attr_accessor :version_code

  # Version name of this apk
  # @return [String] Return a value if it is defined in AndroidManifest.xml, otherwise empty. Never be nil.
  attr_accessor :version_name

  # Min sdk version of this apk
  # @return [String] Return Integer string which is defined in AndroidManifest.xml
  attr_accessor :sdk_version
  alias min_sdk_version sdk_version

  # Target sdk version of this apk
  # @return [String] Return Integer string which is defined in AndroidManifest.xml
  attr_accessor :target_sdk_version

  # The SHA-1 signature of this apk
  # @return [String, nil] Return nil if cannot extract sha1 hash, otherwise the value will be returned.
  attr_accessor :signature

  # Check whether or not this apk's icon is an adaptive icon
  # @return [Boolean] Return true if this apk has an adaptive icon, otherwise false.
  attr_accessor :adaptive_icon
  alias adaptive_icon? adaptive_icon

  # Check whether or not this apk's icon is a backward-compatible adaptive icon for lower sdk
  # @return [Boolean] Return true if this apk is targeting to 25 or less sdk version and has an adaptive icon and a fallback icon, otherwise false.
  attr_accessor :backward_compatible_adaptive_icon
  alias backward_compatible_adaptive_icon? backward_compatible_adaptive_icon

  # Check whether or not this apk is verified
  # @return [Boolean] Return true if this apk is verified, otherwise false.
  attr_accessor :verified
  alias verified? verified

  # Check whether or not this apk is a test mode
  # @return [Boolean] Return true if this apk is a test mode, otherwise false.
  attr_accessor :test_only
  alias test_only? test_only

  # An apk file which has been analyzed
  # @deprecated because a file might be moved/removed
  # @return [String] Return a file path of this apk file
  attr_accessor :filepath

  NOT_ALLOW_DUPLICATE_TAG_NAMES = %w(
    application
    sdkVersion
    targetSdkVersion
  ).freeze

  DPI_TO_NAME_MAP = {
    120 => "ldpi",
    160 => "mdpi",
    240 => "hdpi",
    320 => "xhdpi",
    480 => "xxhdpi",
    640 => "xxxhdpi",
  }.freeze

  SUPPORTED_DPIS = DPI_TO_NAME_MAP.keys.freeze
  SUPPORTED_DPI_NAMES = DPI_TO_NAME_MAP.values.freeze

  module Reason
    UNVERIFIED = :unverified
    TEST_ONLY = :test_only
    UNSIGNED = :unsigned
  end

  # Do analyze the given apk file. Analyzed apk does not mean *valid*.
  #
  # @param [String] filepath a filepath of an apk to be analyzed
  # @return [AndroidApk] An instance of AndroidApk will be returned if no problem exists while analyzing.
  # @raise [AndroidApk::ApkFileNotFoundError] if the filepath doesn't exist
  # @raise [AndroidApk::UnacceptableApkError] if the apk file is not acceptable by commands like aapt
  # @raise [AndroidApk::AndroidManifestValidateError] if the apk contains invalid AndroidManifest.xml but only when we can identify why it's invalid.
  def self.analyze(filepath)
    raise ApkFileNotFoundError, "an apk file is required to analyze." unless File.exist?(filepath)

    apk = AndroidApk.new
    command = "aapt2 dump badging #{filepath.shellescape} 2>&1"
    results = `#{command}`

    if $?.exitstatus != 0
      if results.index(/ERROR:?\s/) # : is never required because it's mixed.
        # *normally* failed. The output of aapk dump is helpful.
        # ref: https://cs.android.com/android/platform/superproject/+/master:frameworks/base/tools/aapt/Command.cpp;l=860?q=%22dump%20failed%22%20aapt
        raise UnacceptableApkError, "This apk file cannot be analyzed using 'aapt dump badging'. #{results}"
      else
        # unexpectedly failed. This may happen due to the running environment.
        raise UnacceptableApkError, "'aapt dump badging' failed due to an unexpected error."
      end
    end

    apk.filepath = filepath
    apk.results = results
    vars = _parse_aapt(results)

    # application info
    apk.label = vars["application-label"]
    apk.icon = vars["application"]["icon"]
    apk.test_only = vars.key?("testOnly='-1'")

    # package

    apk.package_name = vars["package"]["name"]
    apk.version_code = vars["package"]["versionCode"]
    apk.version_name = vars["package"]["versionName"]
    apk.version_name ||= "" # ensure

    # platforms
    apk.sdk_version = vars["sdkVersion"]
    apk.target_sdk_version = vars["targetSdkVersion"]

    # icons and labels
    apk.icons = ({}) # old
    apk.labels = ({})

    vars.each_key do |k|
      if (m = k.match(/\Aapplication-icon-(\d+)\z/))
        apk.icons[m[1].to_i] = vars[k]
      elsif (m = k.match(/\Aapplication-label-(\S+)\z/))
        apk.labels[m[1]] = vars[k]
      end
    end

    # It seems the resources in the aapt's output doesn't mean that it's available in resource.arsc
    icons_in_arsc = ::AndroidApk::ResourceFinder.resolve_icons_in_arsc(
      apk_filepath: filepath,
      default_icon_path: vars["application"]["icon"]
    )

    apk.icon_path_hash = apk.icons.dup.transform_keys { |dpi|
      DPI_TO_NAME_MAP[dpi] || DEFAULT_RESOURCE_CONFIG
    }.merge(icons_in_arsc)

    read_signature(apk, filepath)
    read_adaptive_icon(apk, filepath)

    return apk
  end

  def initialize
    self.adaptive_icon = false
    self.backward_compatible_adaptive_icon = false
    self.verified = false
    self.test_only = false
  end

  # @deprecated no longer used
  # Get an application icon file of this apk file.
  #
  # @param [Integer] dpi one of (see SUPPORTED_DPIS)
  # @param [Boolean] want_png request a png icon expressly
  # @return [File, nil] an application icon file object in temp dir
  def icon_file(dpi = nil, want_png = false)
    icon = dpi ? self.icons[dpi.to_i] : self.icon
    return nil if icon.nil? || icon.empty?

    # Unfroze just in case
    icon = +icon
    dpis = dpi_str(dpi)

    # neat adaptive icon apk
    if want_png && icon.end_with?(".xml")
      icon.gsub!(%r{res/(drawable|mipmap)-anydpi-(?:v\d+)/([^/]+)\.xml}, "res/\\1-#{dpis}-v4/\\2.png")
    end

    # 1st fallback is for WEIRD adaptive icon apk e.g. Cordiva generates such apks
    if want_png && icon.end_with?(".xml")
      icon.gsub!(%r{res/(drawable|mipmap)-.+?dpi-(?:v\d+)/([^/]+)\.xml}, "res/\\1-#{dpis}-v4/\\2.png")
    end

    # 2nd fallback is for vector drawable icon apk. Use a png file which is manually resolved
    if want_png && icon.end_with?(".xml")
      icon.gsub!(%r{res/(drawable|mipmap)/([^/]+)\.xml}, "res/\\1-#{dpis}-v4/\\2.png")
    end

    # we cannot prepare for any fallbacks but don't return nil for now to keep the behavior

    Dir.mktmpdir do |dir|
      output_to = File.join(dir, icon)

      FileUtils.mkdir_p(File.dirname(output_to))

      Zip::File.open(self.filepath) do |zip_file|
        entry = zip_file.find_entry(icon) or return nil

        File.open(output_to, "wb") do |f|
          f.write(zip_file.read(entry))
        end
      end

      return nil unless File.exist?(output_to)

      return File.new(output_to, "r")
    end
  end

  def available_png_icon
    png_path = DPI_TO_NAME_MAP.keys.sort { |i| i }
      .lazy
      .map { |dpi| icon_path_hash[DPI_TO_NAME_MAP[dpi]] }
      .find { |path| path&.end_with?(".png") }

    return if png_path.nil?

    Dir.mktmpdir do |dir|
      output_to = File.join(dir, png_path)
      FileUtils.mkdir_p(File.dirname(output_to))

      Zip::File.open(self.filepath) do |zip_file|
        entry = zip_file.find_entry(png_path)

        next if entry.nil?

        File.open(output_to, "wb") do |f|
          f.write(zip_file.read(entry))
        end
      end

      break unless File.exist?(output_to)

      return File.new(output_to, "r")
    end
  end

  # dpi to android drawable resource config name
  #
  # @param [Integer] dpi one of (see SUPPORTED_DPIS)
  # @return [String] (see SUPPORTED_DPIS). Return "xxxhdpi" if (see dpi) is not in (see SUPPORTED_DPIS)
  def dpi_str(dpi)
    DPI_TO_NAME_MAP[dpi.to_i] || "xxxhdpi"
  end

  # Experimental API!
  # Check whether or not this apk is installable
  # @return [Boolean] Return true if this apk is installable, otherwise false.
  def installable?
    uninstallable_reasons.empty?
  end

  # Experimental API!
  # Reasons why this apk is not installable
  # @return [Array<Symbol>] Return non-empty symbol array which contain reasons, otherwise an empty array.
  def uninstallable_reasons
    reasons = []
    reasons << Reason::UNVERIFIED unless verified?
    reasons << Reason::UNSIGNED unless signed?
    reasons << Reason::TEST_ONLY if test_only?
    reasons
  end

  # Whether or not this apk is signed but this depends on (see signature)
  #
  # @return [Boolean, nil] this apk is signed if true, otherwise not signed.
  def signed?
    !signature.nil?
  end

  def adaptive_icon_density
    min_sdk_version.to_i >= ADAPTIVE_ICON_SDK ? "anydpi" : "anydpi-v26"
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

  # Parse output of aapt command to Hash format
  #
  # @param [String, nil] results output of aapt command. this may be multi lines.
  # @return [Hash, nil] return nil if (see str) is nil. Otherwise the parsed hash will be returned.
  def self._parse_aapt(results)
    vars = {}
    results.split("\n").each do |line|
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
    return vars
  end

  # @param [String] key a key of AndroidManifest.xml
  # @raise [AndroidManifestValidateError] if a key is found in (see NOT_ALLOW_DUPLICATE_TAG_NAMES)
  def self.reject_illegal_duplicated_key!(key)
    raise AndroidManifestValidateError, key if NOT_ALLOW_DUPLICATE_TAG_NAMES.include?(key)
  end

  def self.read_signature(apk, filepath)
    # Use target_sdk_version as min sdk version!
    # Because some of apks are signed by only v2 scheme even though they have 23 and lower min sdk version
    # For now, we use Signer #1 until multiple signers come
    print_certs_command = "apksigner verify --min-sdk-version=#{apk.target_sdk_version} --print-certs #{filepath.shellescape} | grep 'Signer #1' | grep 'SHA-1'"
    certs_hunk, _, exit_status = Open3.capture3(print_certs_command)

    apk.verified = exit_status.success?

    if !exit_status.success? || certs_hunk.nil?
      # For RSA or DSA encryption
      print_certs_command = "unzip -p #{filepath.shellescape} META-INF/*.RSA META-INF/*.DSA | openssl pkcs7 -inform DER -text -print_certs | keytool -printcert | grep SHA1:"
      certs_hunk, _, exit_status = Open3.capture3(print_certs_command)
    end

    if !exit_status.success? || certs_hunk.nil?
      # Use a previous method as a fallback just in case
      print_certs_command = "unzip -p #{filepath.shellescape} META-INF/*.RSA META-INF/*.DSA | keytool -printcert | grep SHA1:"
      certs_hunk, _, exit_status = Open3.capture3(print_certs_command)
    end

    if exit_status.success? && !certs_hunk.nil?
      signatures = certs_hunk.scan(/(?:[0-9a-zA-Z]{2}:?){20}/)
      apk.signature = signatures[0].delete(":").downcase if signatures.length == 1
    else
      apk.signature = nil # make sure being nil
    end
  end

  def self.read_adaptive_icon(apk, filepath)
    # candidate
    adaptive_icon_path = apk.icon or return

    return unless adaptive_icon_path.end_with?(".xml")

    png_dpi = SUPPORTED_DPI_NAMES.find { |d| apk.icon_path_hash[d]&.end_with?(".png") }

    # at least one png icon is required if min sdk version doesn't support adaptive icon
    if apk.min_sdk_version.to_i < ADAPTIVE_ICON_SDK && png_dpi.nil?
      return
    end

    # invalid xml file may throw an error
    Zip::File.open(filepath) do |zip_file|
      apk.adaptive_icon = zip_file.find_entry(adaptive_icon_path)&.get_input_stream do |entry|
        !!entry.read.include?("adaptive-icon")
      end

      break if apk.min_sdk_version.to_i >= ADAPTIVE_ICON_SDK

      apk.backward_compatible_adaptive_icon = apk.adaptive_icon && !zip_file.find_entry(apk.icon_path_hash[png_dpi]).nil?
    end
  end
end
