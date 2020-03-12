# frozen_string_literal: true

module AndroidApk::Aapt
  class ExecutionFailure < AndroidApk::Error
    attr_reader :stderr

    def initialize(message, stderr)
      super(message)
      @stderr = stderr
    end
  end

  class << self
    attr_accessor :aapt_path
  end

  class Executor
    class ShellOptionDto
      def to_args_in_order
        instance_variables.map do |v|
          instance_variable_get(v)
        end
      end
    end

    def execute_aapt(*args)
      stdout, stderr, status = Open3.capture3(*[AndroidApk::Aapt.aapt_path || "aapt", args].flatten)
      raise ExecutionFailure.new("failed to run aapt command", stderr) unless status.success?

      stdout.chomp
    end
  end

  class BumpBadging < Executor
    class Options < ShellOptionDto
      # String
      attr_accessor :apk_file
    end

    attr_reader :apk_file_path

    def initialize(apk_file_path:)
      @apk_file_path = apk_file_path
    end

    def execute!
      raise ::AndroidApk::FileNotFoundError, "#{apk_file_path} does not exist" unless File.exist?(apk_file_path)

      options = Options.new.tap do |o|
        o.apk_file = apk_file_path
      end

      execute_aapt("dump", "badging", *options.to_args_in_order)
    end
  end
end
