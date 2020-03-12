# frozen_string_literal: true

require_relative "../spec_helper"

describe AndroidApk::Aapt do
  let(:valid_apk_filepath_wo_space) { File.join(FIXTURE_DIR, "other", "sample.apk") }
  let(:valid_apk_filepath_w_space) { File.join(FIXTURE_DIR, "other", "sample with space.apk") }
  let(:not_found_apk_filepath) { File.join(FIXTURE_DIR, "other", "    nothing    .apk") }

  shared_context :process do
    describe AndroidApk::Aapt::BumpBadging do
      let(:command) { AndroidApk::Aapt::BumpBadging.new(apk_file_path: apk_file_path) }
      subject { command.execute! }

      context "valid apk w/o space" do
        let(:apk_file_path) { valid_apk_filepath_wo_space }

        it "returns aapt dump results" do
          expect(subject).to include("package")
        end
      end

      context "valid apk w/ space" do
        let(:apk_file_path) { valid_apk_filepath_w_space }

        it "returns aapt dump results" do
          expect(subject).to include("package")
        end
      end

      context "invalid apk that is not found" do
        let(:apk_file_path) { not_found_apk_filepath }

        it "throws a not found exception" do
          expect { subject }.to raise_error(AndroidApk::FileNotFoundError)
        end
      end
    end
  end

  context "without aapt_path option" do
    include_context :process

    it "makes sure aapt_path is nil" do
      expect(AndroidApk::Aapt.aapt_path).to be_nil
    end
  end

  context "with aapt_path option" do
    let(:aapt_path) { "#{ENV.fetch('ANDROID_HOME')}/build-tools/27.0.3/aapt" }

    before do
      AndroidApk::Aapt.aapt_path = aapt_path
    end

    it "makes sure aapt_path is saved" do
      expect(AndroidApk::Aapt.aapt_path).to eq(aapt_path)
    end

    include_context :process
  end
end
