# frozen_string_literal: true

module AndroidApk::Apksigner
  class ExecutionFailure < AndroidApk::Error; end

  class << self
    attr_accessor :apksigner_path
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

    def execute_apksigner(*args)
      stdout, stderr, status = Open3.capture3(*[AndroidApk::Config.apksigner_path || "apksigner", args].flatten)
      raise ExecutionFailure, stderr unless status.success?

      stdout.chomp
    end

    def execute_apksigner_in_pipeline(apksigner_command_args, *cmds)
      apksigner_command = [AndroidApk::Config.apksigner_path || "apksigner", apksigner_command_args].flatten
      stdin_io, stdout_io, stderr_io, wait_thr = Open3.popen3(apksigner_command, *cmds)

      begin
        stdout = stdout_io.read.chomp

        raise ExecutionFailure, stderr_io.read.chomp unless wait_thr.status.success?

        stdout.chomp
      ensure
        stdin_io.close
        stdout_io.close
        stderr_io.close
      end
    end
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

  class VerifySignature < Executor
    class Options < ShellOptionDto

      # String
      attr_accessor :min_sdk_version
    end

    attr_reader :apk_file_path

    def initialize(apk_file_path:)
      @apk_file_path = apk_file_path
    end

    def execute!(min_sdk_version:)
      raise ::AndroidApk::FileNotFoundError, "#{apk_file_path} does not exist" unless File.exist?(apk_file_path)

      options = Options.new.tap do |o|
        o.min_sdk_version = min_sdk_version
      end

      certs_hunk = execute_apksigner_in_pipeline(["verify", *options.to_args], %w(grep Signer #1), %w(grep SHA-1))
      signatures = certs_hunk.scan(/(?:[0-9a-zA-Z]{2}:?){20}/)

      if signatures.size == 1
        signatures[0]
      else
        raise ExecutionFailure, "multiple signatures were found"
      end
    end
  end
end
