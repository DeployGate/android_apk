# frozen_string_literal: true

class AndroidApk
  class Error < StandardError; end

  class AndroidManifestValidateError < Error; end

  class DuplicatedTagError < AndroidManifestValidateError; end

  class FileNotFoundError < Error; end
  class NonAnalyzableError < Error
    attr_reader :original

    def initialize(message, original)
      super(message)
      @original = original
    end
  end
end
