# frozen_string_literal: true

class AndroidApk
  class Configuration
    AAPT = :aapt
    AAPT2 = :aapt2

    class << self
      # @return [AndroidApk::Configuration]
      def defaults
        self.new
      end
    end

    def initialize(resource_finder_type: AAPT)
      @resource_finder_type = resource_finder_type
    end

    # @return [AndroidApk::ResourceFinder]
    def resource_finder
      return @resource_finder if defined?(@resource_finder)

      delegatee = case @resource_finder_type
                  when AAPT
                    ::AndroidApk::Aapt::ResourceFinder
                  when AAPT2
                    ::AndroidApk::Aapt2::ResourceFinder
                  else
                    raise "#{@resource_finder_type} is unknown"
                  end

      @resource_finder = ::AndroidApk::ResourceFinder.new(delegatee: delegatee)
    end

    # @return [AndroidApk::Configuration]
    def copy(
      resource_finder_type: @resource_finder_type
    )
      self.class.new(
        resource_finder_type: resource_finder_type
      )
    end
  end
end
