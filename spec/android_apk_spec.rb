# frozen_string_literal: true

describe "AndroidApk" do
  around(:each) do |example|
    AndroidApk.configure(
      resource_finder: :aapt2
    ) do
      example.run
    end
  end

  describe "#self.analyze" do
    subject { AndroidApk.analyze(apk_filepath) }

    let(:aapt_apk) do
      AndroidApk.configure(resource_finder: :aapt) do
        AndroidApk.analyze(apk_filepath)
      end
    end

    shared_examples_for :analyzable do
      it "should exist" do
        expect(File.exist?(apk_filepath)).to be_truthy
      end

      it "should be analyzable" do
        expect { subject }.not_to raise_exception
      end

      it "should not raise any error when getting an icon file" do
        max_icon = (subject.icons.keys - [65_534, 65_535]).max

        expect { subject.icon_file }.not_to raise_exception
        expect { subject.icon_file(max_icon, false) }.not_to raise_exception
        expect { subject.icon_file(max_icon, true) }.not_to raise_exception
      end

      it "should not raise any error when getting an available png icon file" do
        expect { subject.available_png_icon }.not_to raise_exception
      end

      it "aapt and aapt2 compatibility" do
        expect(subject).to eql(aapt_apk)
      end
    end

    context "if invalid sample apk files are given" do
      cases = [
        {
          filepath: fixture_file("invalid", "no_such_file"),
          error: AndroidApk::ApkFileNotFoundError,
        },
        {
          filepath: fixture_file("invalid", "no_android_manifest.apk"),
          error: AndroidApk::UnacceptableApkError,
        },
        {
          filepath: fixture_file("invalid", "corrupt_manifest.apk"),
          error: AndroidApk::UnacceptableApkError,
          error_message: /AndroidManifest\.xml is corrupt/
        },
        {
          filepath: fixture_file("invalid", "duplicate_sdk_version.apk"),
          error: AndroidApk::AndroidManifestValidateError,
          error_message: /sdkVersion/ # TODO: this field never duplicate since buildtools 30.0.1
        },
        {
          filepath: fixture_file("invalid", "multi_application_tag.apk"),
          error: AndroidApk::AndroidManifestValidateError,
          error_message: /application/
        },
      ]

      cases.each do |c|
        context "for #{c[:filepath]}" do
          let(:apk_filepath) { c[:filepath] }

          it { expect { subject }.to raise_error(c[:error], c[:error_message]) }
        end
      end
    end

    context "if valid sample apk files are given" do
      shared_examples_for :not_test_only do
        it "should not test_only?" do
          expect(subject.test_only?).to be_falsey
        end
      end

      # space check
      ["sample.apk", "sample with space.apk"].each do |apk_name|
        context "#{apk_name} which is a very simple sample" do
          let(:apk_filepath) { File.join(FIXTURE_DIR, "other", apk_name) }

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

      context "noVersionName.apk which doe have version name attribute" do
        let(:apk_filepath) { File.join(FIXTURE_DIR, "other", "noVersionName.apk") }

        include_examples :analyzable

        it "should returns empty string" do
          expect(subject.version_name).to eq("")
        end
      end

      context "test-only.apk which has a testOnly flag" do
        let(:apk_filepath) { File.join(FIXTURE_DIR, "other", "test-only.apk") }

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

      context "unsigned.apk " do
        let(:apk_filepath) { File.join(FIXTURE_DIR, "other", "unsigned.apk") }

        include_examples :analyzable

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

      describe "resource aware specs" do
        let(:apk_filepath) { File.join(FIXTURE_DIR, resource_dir, "apks-#{min_sdk}", apk_name) }

        %w(resources new-resources).each do |res|
          context "in #{res}" do
            let(:resource_dir) { res }

            %w(14 21 26).each do |sdk|
              context "in apks-#{sdk}" do
                let(:min_sdk) { sdk }

                context "png in drawable-*dpi" do
                  let(:apk_name) { "drawablePngIconOnly.apk" }

                  it { expect(subject.available_png_icon).not_to be_nil }
                  it { expect(subject).not_to be_adaptive_icon }
                  it { expect(subject).not_to be_backward_compatible_adaptive_icon }
                  it { expect(subject).to be_installable }

                  it {
                    expect(subject.icon_path_hash).to include(
                      "mdpi" => be_end_with(".png"),
                      "hdpi" => be_end_with(".png"),
                      "xhdpi" => be_end_with(".png"),
                      "xxhdpi" => be_end_with(".png"),
                      "xxxhdpi" => be_end_with(".png")
                    )
                  }
                end

                context "png in mipmap-*api" do
                  let(:apk_name) { "mipmapPngIconOnly.apk" }

                  it { expect(subject.available_png_icon).not_to be_nil }
                  it { expect(subject).not_to be_adaptive_icon }
                  it { expect(subject).not_to be_backward_compatible_adaptive_icon }
                  it { expect(subject).to be_installable }

                  it {
                    expect(subject.icon_path_hash).to include(
                      "mdpi" => be_end_with(".png"),
                      "hdpi" => be_end_with(".png"),
                      "xhdpi" => be_end_with(".png"),
                      "xxhdpi" => be_end_with(".png"),
                      "xxxhdpi" => be_end_with(".png")
                    )
                  }
                end

                context "adaptive icon with png icon" do
                  let(:apk_name) { "adaptiveIconWithPng.apk" }

                  it { expect(subject.available_png_icon).not_to be_nil }
                  it { expect(subject).to be_adaptive_icon }
                  it { expect(subject.backward_compatible_adaptive_icon?).to be_truthy }
                  it { expect(subject).to be_installable }

                  it {
                    expect(subject.icon_path_hash).to include(
                      "mdpi" => be_end_with(".png"),
                      "hdpi" => be_end_with(".png"),
                      "xhdpi" => be_end_with(".png"),
                      "xxhdpi" => be_end_with(".png"),
                      "xxxhdpi" => be_end_with(".png")
                    )
                  }
                end

                context "adaptive icon with png icon and round icons" do
                  let(:apk_name) { "adaptiveIconWithRoundPng.apk" }

                  it { expect(subject.available_png_icon).not_to be_nil }
                  it { expect(subject).to be_adaptive_icon }
                  it { expect(subject.backward_compatible_adaptive_icon?).to be_truthy }
                  it { expect(subject).to be_installable }

                  it {
                    expect(subject.icon_path_hash).to include(
                      "mdpi" => be_end_with(".png"),
                      "hdpi" => be_end_with(".png"),
                      "xhdpi" => be_end_with(".png"),
                      "xxhdpi" => be_end_with(".png"),
                      "xxxhdpi" => be_end_with(".png")
                    )
                  }
                end

                context "vector drawable with png icon" do
                  let(:apk_name) { "vectorDrawableWithPng.apk" }

                  it { expect(subject.available_png_icon).not_to be_nil }
                  it { expect(subject).not_to be_adaptive_icon }
                  it { expect(subject).not_to be_backward_compatible_adaptive_icon }
                  it { expect(subject).to be_installable }
                end

                # unsupported for now

                context "vector drawable icon only", skip: sdk.to_i < 21 do
                  # cannot create this apk since Lollipop
                  let(:apk_name) { "vectorDrawableIconOnly.apk" }

                  it { expect(subject.available_png_icon).to be_nil }
                  it { expect(subject).not_to be_adaptive_icon }
                  it { expect(subject).not_to be_backward_compatible_adaptive_icon }
                  it { expect(subject).to be_installable }
                  it { expect(subject.icon_path_hash).not_to be_empty }
                end

                # edge cases

                context "no icon" do
                  let(:apk_name) { "noIcon.apk" }

                  it { expect(subject.available_png_icon).to be_nil }
                  it { expect(subject).not_to be_adaptive_icon }
                  it { expect(subject).not_to be_backward_compatible_adaptive_icon }
                  it { expect(subject.icon_path_hash).to be_empty }
                  it { expect(subject).to be_installable }
                end

                context "misconfigured adaptive icon" do
                  let(:apk_name) { "misconfiguredAdaptiveIcon.apk" }

                  it { expect(subject.available_png_icon).to be_nil }
                  # adaptive icon doesn't need a png icon if min sdk version is equal to or newer than 26
                  it { expect(subject.adaptive_icon?).to eq(sdk.to_i >= 26) }
                  it { expect(subject).not_to be_backward_compatible_adaptive_icon }
                  it { expect(subject).to be_installable }
                end

                context "png only in drawable" do
                  let(:apk_name) { "drawablePngIconOnly.apk" }

                  it { expect(subject.available_png_icon).not_to be_nil }
                  it { expect(subject).not_to be_adaptive_icon }
                  it { expect(subject).not_to be_backward_compatible_adaptive_icon }
                  it { expect(subject).to be_installable }
                end
              end
            end
          end
        end
      end

      describe "signature aware specs" do
        let(:signatures) do
          {
            "rsa" => "4ad4e4376face4e441a3b8802363a7f6c6b458ab",
            "dsa" => "6a2dd3e16a3f05fc219f914734374065985273b3"
          }
        end

        let(:apk_filepath) { File.join(FIXTURE_DIR, "signatures", "apks-#{min_sdk}-v1-#{v1_enabled}-v2-#{v2_enabled}/#{signing}/app-#{signing}.apk") }

        %w(rsa dsa).each do |sig_method|
          context "signed with #{sig_method}" do
            let(:signing) { sig_method }
            let(:signature) { signatures[signing] }

            %w(14 24).each do |sdk|
              context "in apks-#{sdk}" do
                let(:min_sdk) { sdk }

                [
                  [true, true],
                  [true, false],
                  [false, true]
                ].each do |v1, v2|
                  context "v1 signed? == #{v1} and v2 signed? == #{v2}" do
                    let(:v1_enabled) { v1 }
                    let(:v2_enabled) { v2 }

                    it { expect(subject.signature).to eq(signature) }
                    it { expect(subject).to be_signed }
                    it { expect(subject).to be_installable }
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  describe "#available_png_icon" do
    subject { AndroidApk.analyze(apk_filepath).available_png_icon }

    let(:comparator) do
      MiniMagick::Tool::Compare.new(whiny: false).tap do |c|
        c.metric("AE")
      end
    end

    Dir.glob("#{FIXTURE_DIR}/*resources/**/*.apk").each do |apk_name|
      context apk_name.to_s do
        let(:apk_filepath) { apk_name }
        let(:correct_icon_filepath) { apk_filepath.split("/").yield_self { |paths| File.join(*paths.insert(paths.index("fixture") + 1, "oracle")) }.gsub(/\.apk\z/, ".png") }

        let(:temp_dir) { Dir.mktmpdir }
        let(:generated_icon_filepath) { File.join(temp_dir, "#{File.basename(apk_name)}.png") }

        before do
          generated_icon_filepath
        end

        after do
          FileUtils.remove_entry(temp_dir)
        end

        it "no *diff* is expected" do
          if File.exist?(correct_icon_filepath)
            is_expected.to be_truthy

            File.binwrite(generated_icon_filepath, subject.read)

            comparator << generated_icon_filepath
            comparator << correct_icon_filepath
            comparator << File.join(temp_dir, "diff")

            comparator.call do |_, dist, _|
              expect(dist.to_i).to be_zero
            end
          else
            is_expected.to be_nil
          end
        end
      end
    end
  end

  describe "#app_icons" do
    let(:apk_filepath) { File.join(FIXTURE_DIR, "new-resources", "apks-21", "adaptiveIconWithPng.apk") }
    let(:apk) { AndroidApk.analyze(apk_filepath) }
    let(:app_icons) { apk.app_icons }

    it "returns an array ordered by dpi desc" do
      expect(app_icons.map(&:metadata)).to eq([
                                                {
                                                  dpi: 8026,
                                                  resource_path: "res/uF.xml"
                                                },
                                                {
                                                  dpi: 640,
                                                  resource_path: "res/CG.png"
                                                },
                                                {
                                                  dpi: 480,
                                                  resource_path: "res/D2.png"
                                                },
                                                {
                                                  dpi: 320,
                                                  resource_path: "res/jy.png"
                                                },
                                                {
                                                  dpi: 240,
                                                  resource_path: "res/SD.png"
                                                },
                                                {
                                                  dpi: 160,
                                                  resource_path: "res/u3.png"
                                                },
                                                {
                                                  dpi: 100,
                                                  resource_path: "res/uF.xml"
                                                }
                                              ])
    end
  end

  describe "#app_icons and #available_png_icon compatibility" do
    let(:apk) { AndroidApk.analyze(apk_filepath) }
    let(:app_icons) { apk.app_icons }
    let(:available_png_icon) { apk.available_png_icon }

    let(:comparator) do
      MiniMagick::Tool::Compare.new(whiny: false).tap do |c|
        c.metric("AE")
      end
    end

    Dir.glob("#{FIXTURE_DIR}/*resources/**/*.apk").each do |apk_name|
      context apk_name.to_s do
        let(:apk_filepath) { apk_name }
        let(:correct_icon_filepath) { apk_filepath.split("/").yield_self { |paths| File.join(*paths.insert(paths.index("fixture") + 1, "oracle")) }.gsub(/\.apk\z/, ".png") }

        let(:temp_dir) { Dir.mktmpdir }
        let(:available_png_icon_filepath) { File.join(temp_dir, "#{File.basename(apk_name)}-available-png-icon.png") }
        let(:app_icons_filepath) { File.join(temp_dir, "#{File.basename(apk_name)}-app_icons.png") }

        before do
          available_png_icon_filepath
          app_icons_filepath
        end

        after do
          FileUtils.remove_entry(temp_dir)
        end

        it "no *diff* is expected" do
          if File.exist?(correct_icon_filepath)
            # first png element in app_icons must be same to available_png_icon

            File.binwrite(available_png_icon_filepath, available_png_icon.read)

            File.open(app_icons_filepath, "wb") do |f|
              app_icons.find(&:png?).open do |png|
                f.write(png.read)
              end
            end

            comparator << available_png_icon_filepath
            comparator << app_icons_filepath
            comparator << File.join(temp_dir, "diff")

            comparator.call do |_, dist, _|
              expect(dist.to_i).to be_zero
            end
          else
            expect(app_icons.any?(&:png?)).to be_falsey
          end
        end
      end
    end
  end
end
