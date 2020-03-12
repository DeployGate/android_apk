# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "version.rb"

Gem::Specification.new do |spec|
  spec.name = "android_apk"
  spec.version = AndroidApk::VERSION
  spec.authors = ["DeployGate, Inc."]
  spec.email = ["help@deploygate.com"]
  spec.date = "2020-03-12"
  spec.description = "This library can analyze Android APK application package. You can get any information of android apk file. Originally developed by Kyosuke Inoue (kyoro@hakamastyle.net)"
  spec.summary = "Android APK file analyzer"
  spec.homepage = "https://github.com/DeployGate/android_apk"
  spec.license = "MIT"

  spec.files = `git ls-files | grep -v 'spec/fixture'`.split($/)
  spec.test_files = spec.files.grep(%r{^(test|spec)/})
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = %w(LICENSE.txt README.md)

  spec.add_dependency "rubyzip", ">= 1.2.3"

  # General ruby development
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", "~> 10.0"

  # Testing support
  spec.add_development_dependency "rspec", "~> 3.4"
  spec.add_development_dependency "simplecov"

  # Linting code and docs
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "yard"

  # Makes testing easy via `bundle exec guard`
  spec.add_development_dependency "guard", "~> 2.14"
  spec.add_development_dependency "guard-rspec", "~> 4.7"

  spec.add_development_dependency "pry"
end
