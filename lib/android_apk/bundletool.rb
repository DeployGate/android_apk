# frozen_string_literal: true

module AndroidApk::Bundletool
  class ExecutionFailure < AndroidApk::Error
    attr_reader :stderr

    def initialize(message, stderr)
      super(message)
      @stderr = stderr
    end
  end

  class << self
    attr_reader :bundletool_path

    def bundletool_path=(bundletool_path)
      if bundletool_path&.end_with?(".jar")
        @bundletool_path = "java -jar #{bundletool_path}"
      else
        @bundletool_path = bundletool_path
      end
    end
  end

  class Executor
    class ShellOptionDto
      def to_args
        instance_variables.map do |v|
          # Drop '@'
          opt_name = v[1, v.length].tr("_", "-")

          "--#{opt_name}=#{instance_variable_get(v)}"
        end
      end
    end

    def execute_bundletool(*args)
      bundletool_path = AndroidApk::Bundletool.bundletool_path || "bundletool"
      stdout, stderr, status = Open3.capture3(*[bundletool_path, args].flatten)
      raise ExecutionFailure.new("failed to manipulate app bundle file", stderr) unless status.success?

      stdout.chomp
    end
  end

  class BumpManifest < Executor
    class Options < ShellOptionDto
      # String
      attr_accessor :bundle, :xpath
    end

    attr_reader :aab_file_path

    def initialize(aab_file_path:)
      @aab_file_path = aab_file_path
    end

    def execute!(xpath:)
      raise ::AndroidApk::FileNotFoundError, "#{aab_file_path} does not exist" unless File.exist?(aab_file_path)

      options = Options.new.tap do |o|
        o.bundle = aab_file_path
        o.xpath = xpath
      end

      execute_bundletool("dump", "manifest", *options.to_args)
    end
  end

  class Validate < Executor
    class Options < ShellOptionDto
      # String
      attr_accessor :bundle
    end

    attr_reader :aab_file_path

    def initialize(aab_file_path:)
      @aab_file_path = aab_file_path
    end

    def execute!
      raise ::AndroidApk::FileNotFoundError, "#{aab_file_path} does not exist" unless File.exist?(aab_file_path)

      options = Options.new.tap do |o|
        o.bundle = aab_file_path
      end

      execute_bundletool("validate", *options.to_args)
    end
  end

  class BuildApks < Executor
    class Options < ShellOptionDto
      MODE_UNIVERSAL = "universal"

      # String
      attr_accessor :bundle, :output
      # Boolean
      attr_accessor :overwrite
      # Enum
      attr_accessor :mode

      # Keystore
      attr_accessor :ks, :ks_key_alias, :ks_pass, :key_pass
    end

    attr_reader :aab_file_path, :output_to

    def initialize(aab_file_path:, output_to:)
      @aab_file_path = aab_file_path
      @output_to = output_to
    end

    def execute!(overwrite:, mode:, ks:, ks_key_alias:, ks_pass:, key_pass:)
      raise ::AndroidApk::FileNotFoundError, "#{aab_file_path} does not exist" unless File.exist?(aab_file_path)

      options = Options.new.tap do |o|
        o.bundle = aab_file_path
        o.output = output_to
        o.overwrite = overwrite
        o.mode = mode
        o.ks = ks
        o.ks_key_alias = ks_key_alias
        o.ks_pass = ks_pass
        o.key_pass = key_pass
      end

      execute_bundletool("build-apks", *options.to_args)
    end
  end
end
