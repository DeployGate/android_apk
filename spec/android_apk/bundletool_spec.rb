# frozen_string_literal: true

require_relative "../spec_helper"

describe AndroidApk::Bundletool do
  let(:valid_aab_filepath_wo_space) { File.join(FIXTURE_DIR, "aab", "sample.aab") }
  let(:valid_aab_filepath_w_space) { File.join(FIXTURE_DIR, "aab", "sample with space.aab") }
  let(:not_found_aab_filepath) { File.join(FIXTURE_DIR, "aab", "    nothing    .aab") }

  shared_context :process do
    describe AndroidApk::Bundletool::BumpManifest do
      let(:command) { AndroidApk::Bundletool::BumpManifest.new(aab_file_path: aab_file_path) }
      subject { command.execute!(xpath: "/manifest/@package") }

      context "valid aab w/o space" do
        let(:aab_file_path) { valid_aab_filepath_wo_space }

        it "returns bump manifest results" do
          expect(subject).to eq("com.deploygate.sample")
        end
      end

      context "valid aab w/ space" do
        let(:aab_file_path) { valid_aab_filepath_w_space }

        it "returns bump manifest results" do
          expect(subject).to eq("com.deploygate.sample")
        end
      end

      context "invalid aab that is not found" do
        let(:aab_file_path) { not_found_aab_filepath }

        it "throws a not found exception" do
          expect { subject }.to raise_error(AndroidApk::FileNotFoundError)
        end
      end
    end

    describe AndroidApk::Bundletool::Validate do
      let(:command) { AndroidApk::Bundletool::Validate.new(aab_file_path: aab_file_path) }
      subject { command.execute! }

      context "valid aab w/o space" do
        let(:aab_file_path) { valid_aab_filepath_wo_space }

        it "returns be valid" do
          expect(subject).to be_truthy
        end
      end

      context "valid aab w/ space" do
        let(:aab_file_path) { valid_aab_filepath_w_space }

        it "returns be valid" do
          expect(subject).to be_truthy
        end
      end

      context "invalid aab that is not found" do
        let(:aab_file_path) { not_found_aab_filepath }

        it "throws a not found exception" do
          expect { subject }.to raise_error(AndroidApk::FileNotFoundError)
        end
      end
    end

    describe AndroidApk::Bundletool::BuildApks do
      let(:f) { Tempfile.new(["dummy", ".apks"]) }
      let(:command) { AndroidApk::Bundletool::BuildApks.new(aab_file_path: aab_file_path, output_to: f.path) }
      let(:ks) { File.join(FIXTURE_DIR, "aab", "debug.keystore") }
      let(:ks_key_alias) { "androiddebugkey" }
      let(:ks_pass) { "android" }
      let(:key_pass) { "android" }

      subject do
        command.execute!(
          overwrite: true,
          mode: AndroidApk::Bundletool::BuildApks::Options::MODE_UNIVERSAL,
          ks: ks,
          ks_key_alias: ks_key_alias,
          ks_pass: "pass:#{ks_pass}",
          key_pass: "pass:#{key_pass}"
        )
      end

      after do
        f.close
      end

      context "valid aab w/o space" do
        let(:aab_file_path) { valid_aab_filepath_wo_space }

        it "returns be valid" do
          expect(subject).to be_truthy
        end
      end

      context "valid aab w/ space" do
        let(:aab_file_path) { valid_aab_filepath_w_space }

        it "returns be valid" do
          expect(subject).to be_truthy
        end
      end

      context "invalid aab that is not found" do
        let(:aab_file_path) { not_found_aab_filepath }

        it "throws a not found exception" do
          expect { subject }.to raise_error(AndroidApk::FileNotFoundError)
        end
      end
    end
  end

  context "without bundletool_path option" do
    include_context :process

    it "makes sure bundletool_path is nil" do
      expect(AndroidApk::Bundletool.bundletool_path).to be_nil
    end
  end

  context "with bundletool_path option" do
    let(:bundletool_path) { "#{ENV.fetch('PWD')}/bin/bundletool" }

    before do
      AndroidApk::Bundletool.bundletool_path = bundletool_path
    end

    it "makes sure bundletool_path is saved" do
      expect(AndroidApk::Bundletool.bundletool_path).to eq(bundletool_path)
    end

    include_context :process
  end
end
