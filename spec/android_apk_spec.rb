# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + "/spec_helper")

describe "AndroidApk" do
  let(:subject_apk) { AndroidApk.analyze(apk_filepath) }

  FIXTURE_DIR = File.join(File.dirname(__FILE__), "mock")

  context "if invalid sample apk files are given" do
    context "no such apk file" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "no_such_file") }

      it "should not exist" do
        expect(File.exist?(apk_filepath)).to be_falsey
      end

      it "should not raise any exception but not be analyzable" do
        expect(subject_apk).to be_nil
      end
    end

    context "not an apk file" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "dummy.apk") }

      it "should exist" do
        expect(File.exist?(apk_filepath)).to be_truthy
      end

      it "should not raise any exception but not be analyzable" do
        expect(subject_apk).to be_nil
      end
    end

    context "multi_application_tag.apk which has multiple application tags" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "multi_application_tag.apk") }

      it "should exist" do
        expect(File.exist?(apk_filepath)).to be_truthy
      end

      it "should raise error" do
        expect { subject_apk }.to raise_error(AndroidApk::AndroidManifestValidateError)
      end
    end
  end

  context "if valid sample apk files are given" do
    %w(sample.apk sample\ with\ space.apk).each do |apk_name|
      context "#{apk_name} which is a very simple sample" do
        let(:apk_filepath) { File.join(FIXTURE_DIR, apk_name) }

        it "should exist" do
          expect(File.exist?(apk_filepath)).to be_truthy
        end

        it "should be analyzable" do
          expect(subject_apk).not_to be_nil
        end

        it "should have icon drawable" do
          expect(subject_apk.icon).to eq("res/drawable-mdpi/ic_launcher.png")
        end

        it "should have label stuff" do
          expect(subject_apk.label).to eq("sample")
          expect(subject_apk.labels).to include("ja" => "サンプル")
          expect(subject_apk.labels.size).to eq(1)
        end

        it "should have package stuff" do
          expect(subject_apk.package_name).to eq("com.example.sample")
          expect(subject_apk.version_code).to eq("1")
          expect(subject_apk.version_name).to eq("1.0")
        end

        it "should have sdk version stuff" do
          expect(subject_apk.sdk_version).to eq("7")
          expect(subject_apk.target_sdk_version).to eq("15")
        end

        it "should have signature" do
          expect(subject_apk.signature).to eq("c1f285f69cc02a397135ed182aa79af53d5d20a1")
        end

        it "should multiple icons for each dimensions" do
          expect(subject_apk.icons.length).to eq(3)
          expect(subject_apk.icons.keys.empty?).to be_falsey
          expect(subject_apk.icon_file).not_to be_nil
          expect(subject_apk.icon_file(subject_apk.icons.keys[0])).not_to be_nil
        end

        it "should be signed" do
          expect(subject_apk.signed?).to be_truthy
        end

        it "should be installable" do
          expect(subject_apk.installable?).to be_truthy
        end
      end
    end

    context "BarcodeScanner4.2.apk whose icon is in drawable dir" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "BarcodeScanner4.2.apk") }

      it "should exist" do
        expect(File.exist?(apk_filepath)).to be_truthy
      end

      it "should be analyzable" do
        expect(subject_apk).not_to be_nil
      end

      it "should have icon drawable" do
        expect(subject_apk.icon).to eq("res/drawable/launcher_icon.png")
      end

      it "should have label stuff" do
        expect(subject_apk.label).to eq("Barcode Scanner")
        expect(subject_apk.labels).to include("ja" => "QRコードスキャナー")
        expect(subject_apk.labels.size).to eq(29)
      end

      it "should have package stuff" do
        expect(subject_apk.package_name).to eq("com.google.zxing.client.android")
        expect(subject_apk.version_code).to eq("84")
        expect(subject_apk.version_name).to eq("4.2")
      end

      it "should have sdk version stuff" do
        expect(subject_apk.sdk_version).to eq("7")
        expect(subject_apk.target_sdk_version).to eq("7")
      end

      it "should have signature" do
        expect(subject_apk.signature).to eq("e460df681d330f93f92e712cd79985d99379f5e0")
      end

      it "should multiple icons for each dimensions" do
        expect(subject_apk.icons.length).to eq(3)
        expect(subject_apk.icons.keys.empty?).to be_falsey
        expect(subject_apk.icon_file).not_to be_nil
        expect(subject_apk.icon_file(120)).not_to be_nil
        expect(subject_apk.icon_file(160)).not_to be_nil
        expect(subject_apk.icon_file(240)).not_to be_nil
        expect(subject_apk.icon_file("120")).not_to be_nil
      end

      it "should be signed" do
        expect(subject_apk.signed?).to be_truthy
      end

      it "should be installable" do
        expect(subject_apk.installable?).to be_truthy
      end
    end

    context "app-release-unsigned.apk which is not signed" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "app-release-unsigned.apk") }

      it "should exist" do
        expect(File.exist?(apk_filepath)).to be_truthy
      end

      it "should be analyzable" do
        expect(subject_apk).not_to be_nil
      end

      it "should not be signed" do
        expect(subject_apk.signed?).to be_falsey
      end

      it "should not expose signature" do
        expect(subject_apk.signature).to be_nil
      end

      it "should not be installable" do
        expect(subject_apk.installable?).to be_falsey
      end
    end

    context "UECExpress.apk which does not have icons" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "UECExpress.apk") }

      it "should exist" do
        expect(File.exist?(apk_filepath)).to be_truthy
      end

      it "should be analyzable" do
        expect(subject_apk).not_to be_nil
      end

      it "should be no icon file" do
        expect(subject_apk.icon_file).to be_nil
        expect(subject_apk.icon_file(nil, true)).to be_nil
      end

      it "should be installable" do
        expect(subject_apk.installable?).to be_truthy
      end
    end

    context "dsa.apk which has been signed with DSA" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "dsa.apk") }

      it "should exist" do
        expect(File.exist?(apk_filepath)).to be_truthy
      end

      it "should be analyzable" do
        expect(subject_apk).not_to be_nil
      end

      it "should also return its signature" do
        expect(subject_apk.signature).to eq("2d8068f79a5840cbce499b51821aaa6c775ff3ff")
      end

      it "should be installable" do
        expect(subject_apk.installable?).to be_truthy
      end
    end

    %w(vector-icon.apk vector-icon-v26.apk).each do |apk_name|
      context "#{apk_name} whose icon is a vector file" do
        let(:apk_filepath) { File.join(FIXTURE_DIR, apk_name) }

        it "should exist" do
          expect(File.exist?(apk_filepath)).to be_truthy
        end

        it "should be analyzable" do
          expect(subject_apk).not_to be_nil
        end

        it "should have non-png icon" do
          expect(subject_apk.icon_file).not_to be_nil
        end

        it "should have png icon" do
          expect(subject_apk.icon_file(nil, true)).not_to be_nil
        end

        it "should return png icon by specific dpi" do
          expect(subject_apk.icon_file(240, true)).not_to be_nil
        end

        it "should be installable" do
          expect(subject_apk.installable?).to be_truthy
        end
      end
    end
  end
end
