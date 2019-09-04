# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + "/spec_helper")

describe "AndroidApk" do
  subject { AndroidApk.analyze(apk_filepath) }

  FIXTURE_DIR = File.join(File.dirname(__FILE__), "mock")

  shared_examples_for :analyzable do
    it "should exist" do
      expect(File.exist?(apk_filepath)).to be_truthy
    end

    it "should be analyzable" do
      expect(subject).not_to be_nil
    end

    it "should not raise any error when getting an icon file" do
      max_icon = (subject.icons.keys - [65_534, 65_535]).max

      expect { subject.icon_file }.not_to raise_exception
      expect { subject.icon_file(max_icon, false) }.not_to raise_exception
      expect { subject.icon_file(max_icon, true) }.not_to raise_exception
    end
  end

  context "if invalid sample apk files are given" do
    context "no such apk file" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "no_such_file") }

      it "should not exist" do
        expect(File.exist?(apk_filepath)).to be_falsey
      end

      it "should not raise any exception but not be analyzable" do
        expect(subject).to be_nil
      end
    end

    context "not an apk file" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "dummy.apk") }

      it "should exist" do
        expect(File.exist?(apk_filepath)).to be_truthy
      end

      it "should not raise any exception but not be analyzable" do
        expect(subject).to be_nil
      end
    end

    context "multi_application_tag.apk which has multiple application tags" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "multi_application_tag.apk") }

      it "should exist" do
        expect(File.exist?(apk_filepath)).to be_truthy
      end

      it "should raise error" do
        expect { subject }.to raise_error(AndroidApk::AndroidManifestValidateError)
      end
    end
  end

  context "if valid sample apk files are given" do
    shared_examples_for :not_test_only do
      it "should not test_only?" do
        expect(subject.test_only?).to be_falsey
      end
    end

    %w(sample.apk sample\ with\ space.apk).each do |apk_name|
      context "#{apk_name} which is a very simple sample" do
        let(:apk_filepath) { File.join(FIXTURE_DIR, apk_name) }

        include_examples :analyzable
        include_examples :not_test_only

        it "should have icon drawable" do
          expect(subject.icon).to eq("res/drawable-mdpi/ic_launcher.png")
        end

        it "should have label stuff" do
          expect(subject.label).to eq("sample")
          expect(subject.labels).to include("ja" => "サンプル")
          expect(subject.labels.size).to eq(1)
        end

        it "should have package stuff" do
          expect(subject.package_name).to eq("com.example.sample")
          expect(subject.version_code).to eq("1")
          expect(subject.version_name).to eq("1.0")
        end

        it "should have sdk version stuff" do
          expect(subject.sdk_version).to eq("7")
          expect(subject.target_sdk_version).to eq("15")
        end

        it "should have signature" do
          expect(subject.signature).to eq("c1f285f69cc02a397135ed182aa79af53d5d20a1")
        end

        it "should multiple icons for each dimensions" do
          expect(subject.icons.length).to eq(3)
          expect(subject.icons.keys.empty?).to be_falsey
          expect(subject.icon_file).not_to be_nil
          expect(subject.icon_file(subject.icons.keys[0])).not_to be_nil
        end

        it "should be signed" do
          expect(subject.signed?).to be_truthy
        end

        it "should be installable" do
          expect(subject.installable?).to be_truthy
        end

        it "should not be adaptive icon" do
          expect(subject.adaptive_icon?).to be_falsey
        end
      end
    end

    context "BarcodeScanner4.2.apk whose icon is in drawable dir" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "BarcodeScanner4.2.apk") }

      include_examples :analyzable
      include_examples :not_test_only

      it "should have icon drawable" do
        expect(subject.icon).to eq("res/drawable/launcher_icon.png")
      end

      it "should have label stuff" do
        expect(subject.label).to eq("Barcode Scanner")
        expect(subject.labels).to include("ja" => "QRコードスキャナー")
        expect(subject.labels.size).to eq(29)
      end

      it "should have package stuff" do
        expect(subject.package_name).to eq("com.google.zxing.client.android")
        expect(subject.version_code).to eq("84")
        expect(subject.version_name).to eq("4.2")
      end

      it "should have sdk version stuff" do
        expect(subject.sdk_version).to eq("7")
        expect(subject.target_sdk_version).to eq("7")
      end

      it "should have signature" do
        expect(subject.signature).to eq("e460df681d330f93f92e712cd79985d99379f5e0")
      end

      it "should multiple icons for each dimensions" do
        expect(subject.icons.length).to eq(3)
        expect(subject.icons.keys.empty?).to be_falsey
        expect(subject.icon_file).not_to be_nil
        expect(subject.icon_file(120)).not_to be_nil
        expect(subject.icon_file(160)).not_to be_nil
        expect(subject.icon_file(240)).not_to be_nil
        expect(subject.icon_file("120")).not_to be_nil
      end

      it "should be signed" do
        expect(subject.signed?).to be_truthy
      end

      it "should be installable" do
        expect(subject.installable?).to be_truthy
      end

      it "should not be adaptive icon" do
        expect(subject.adaptive_icon?).to be_falsey
      end
    end

    context "app-release-unsigned.apk which is not signed" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "app-release-unsigned.apk") }

      include_examples :analyzable
      include_examples :not_test_only

      it "should not be signed" do
        expect(subject.signed?).to be_falsey
      end

      it "should not expose signature" do
        expect(subject.signature).to be_nil
      end

      it "should not be installable" do
        expect(subject.installable?).to be_falsey
      end

      it "should have unsigned state" do
        expect(subject.uninstallable_reasons).to include(AndroidApk::Reason::UNSIGNED)
      end
    end

    context "UECExpress.apk which does not have icons" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "UECExpress.apk") }

      include_examples :analyzable
      include_examples :not_test_only

      it "should be no icon file" do
        expect(subject.icon_file).to be_nil
        expect(subject.icon_file(nil, true)).to be_nil
      end

      it "should be installable" do
        expect(subject.installable?).to be_truthy
      end
    end

    context "dsa.apk which has been signed with DSA" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "dsa.apk") }

      include_examples :analyzable
      include_examples :not_test_only

      it "should also return its signature" do
        expect(subject.signature).to eq("2d8068f79a5840cbce499b51821aaa6c775ff3ff")
      end

      it "should be installable" do
        expect(subject.installable?).to be_truthy
      end
    end

    shared_examples :vector_icon_apk do
      include_examples :analyzable
      include_examples :not_test_only

      it "should have non-png icon" do
        expect(subject.icon_file).not_to be_nil
      end

      it "should return png icon by specific dpi" do
        expect(subject.icon_file(240, true)).not_to be_nil
      end
    end

    context "vector-icon.apk whose icon is a vector file" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "vector-icon.apk") }

      it_should_behave_like :vector_icon_apk

      it "should have png icon" do
        expect(subject.icon_file(nil, true)).not_to be_nil
      end

      it "should not be adaptive icon" do
        expect(subject.adaptive_icon?).to be_falsey
      end

      it "should be installable" do
        expect(subject.installable?).to be_truthy
      end
    end

    context "vector-icon-v26.apk whose icon is an adaptive icon" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "vector-icon-v26.apk") }

      it_should_behave_like :vector_icon_apk

      it "should have png icon" do
        expect(subject.icon_file(nil, true)).not_to be_nil
      end

      it "should be an adaptive icon" do
        expect(subject.adaptive_icon?).to be_truthy
      end

      it "should be installable" do
        expect(subject.installable?).to be_truthy
      end
    end

    %w(vector-icon-v26-non-adaptive-icon.apk vector-icon-v26-non-adaptive-icon\ with\ space.apk).each do |apk_name|
      context "#{apk_name} whose icon is not an adaptive icon" do
        let(:apk_filepath) { File.join(FIXTURE_DIR, apk_name) }

        it_should_behave_like :vector_icon_apk

        it "should not have png icon" do
          expect(subject.icon_file(nil, true)).to be_nil
        end

        it "should be an adaptive icon" do
          expect(subject.adaptive_icon?).to be_falsey
        end

        it "should not be installable" do
          expect(subject.installable?).to be_falsey
        end

        it "should have unverified state" do
          expect(subject.uninstallable_reasons).to include(AndroidApk::Reason::UNVERIFIED)
        end
      end
    end

    context "test-only.apk which has a testOnly flag" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "test-only.apk") }

      include_examples :analyzable

      it "should also return its signature" do
        expect(subject.signature).to eq("89f20f82fad1be0f69d273bbdd62503e692d61b0")
      end

      it "should be signed" do
        expect(subject.signed?).to be_truthy
      end

      it "should be test_only?" do
        expect(subject.test_only?).to be_truthy
      end

      it "should not be installable" do
        expect(subject.installable?).to be_falsey
      end

      it "should have test only state" do
        expect(subject.uninstallable_reasons).to include(AndroidApk::Reason::TEST_ONLY)
      end
    end

    shared_examples_for :v2_only_signed do |apk_name|
      include_examples :analyzable
      include_examples :not_test_only

      it "should have signature" do
        expect(subject.signature).to eq("89f20f82fad1be0f69d273bbdd62503e692d61b0")
      end

      it "should be signed" do
        expect(subject.signed?).to be_truthy
      end

      it "should be installable" do
        expect(subject.installable?).to be_truthy
      end
    end


    context "v2-only-sign-with-min-sdk-24.apk which is signed by only v2 scheme" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, 'v2-only-sign-with-min-sdk-24.apk') }

      include_examples :v2_only_signed

      it 'should have 24 as sdk version' do
        expect(subject.sdk_version).to eq('24')
      end
    end

    context "v2-only-sign-with-lower-min-sdk.apk which is signed by only v2 scheme" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, 'v2-only-sign-with-lower-min-sdk.apk') }

      include_examples :v2_only_signed

      it 'should have 14 as sdk version' do
        expect(subject.sdk_version).to eq('14')
      end
    end
  end
end
