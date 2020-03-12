# frozen_string_literal: true

require_relative "../spec_helper"

describe AndroidApk::Config do
  subject(:config) { AndroidApk::Config.new }

  context "#strict" do
    before do
      config.strict = strict
    end

    context "true" do
      let(:strict) { true }

      it "returns true" do
        expect(config.strict).to be_truthy
      end
    end

    context "false" do
      let(:strict) { false }

      it "returns false" do
        expect(config.strict).to be_falsey
      end
    end
  end

  context "#aapt_path=" do
    before do
      allow(AndroidApk::Aapt).to receive(:aapt_path=)

      config.aapt_path = aapt_path
    end

    shared_examples :propagate do
      it "propagates to AndroidApk::Aapt" do
        expect(AndroidApk::Aapt).to have_received(:aapt_path=).with(aapt_path)
      end
    end

    context "nil" do
      let(:aapt_path) { nil }

      include_examples :propagate
    end

    context "any value" do
      let(:aapt_path) { "abc" }

      include_examples :propagate
    end
  end

  context "#bundletool_path=" do
    before do
      allow(AndroidApk::Bundletool).to receive(:bundletool_path=)

      config.bundletool_path = bundletool_path
    end

    shared_examples :propagate do
      it "propagates to AndroidApk::Bundletool" do
        expect(AndroidApk::Bundletool).to have_received(:bundletool_path=).with(bundletool_path)
      end
    end

    context "nil" do
      let(:bundletool_path) { nil }

      include_examples :propagate
    end

    context "any value" do
      let(:bundletool_path) { "abc" }

      include_examples :propagate
    end
  end
end
