# frozen_string_literal: true

describe AndroidApk::Aapt2::ResourceFinder do
  describe "#resolve_icons_in_arsc" do
    subject { AndroidApk::Aapt2::ResourceFinder.resolve_icons_in_arsc(apk_filepath: apk_filepath, default_icon_path: default_icon_path) }
    let(:default_icon_path) { AndroidApk.analyze(apk_filepath).icon }

    context "sample.apk" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "other", "sample.apk") }

      it do
        is_expected.to eq(
                         "hdpi-v4" => "res/drawable-hdpi/ic_launcher.png",
                         "mdpi-v4" => "res/drawable-mdpi/ic_launcher.png",
                         "xhdpi-v4" => "res/drawable-xhdpi/ic_launcher.png"
                       )
      end
    end

    context "sample with space.apk" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "other", "sample with space.apk") }

      it do
        is_expected.to eq(
                         "hdpi-v4" => "res/drawable-hdpi/ic_launcher.png",
                         "mdpi-v4" => "res/drawable-mdpi/ic_launcher.png",
                         "xhdpi-v4" => "res/drawable-xhdpi/ic_launcher.png"
                       )
      end
    end

    # emulate
    context "sample.apk includes non UTF-8" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "other", "sample.apk") }
      let(:aapt_output) do
        stdout = AndroidApk::Aapt2::ResourceFinder.dump_resource_values(apk_filepath: apk_filepath)
        (+"#{stdout}\xFF").force_encoding("UTF-8")
      end

      before do
        allow(AndroidApk::Aapt2::ResourceFinder).to receive(:dump_resource_values).and_return(aapt_output) # inject
      end

      it { expect { aapt_output.split('\n') }.to raise_error(ArgumentError, "invalid byte sequence in UTF-8") }

      it do
        is_expected.to eq(
                         "hdpi-v4" => "res/drawable-hdpi/ic_launcher.png",
                         "mdpi-v4" => "res/drawable-mdpi/ic_launcher.png",
                         "xhdpi-v4" => "res/drawable-xhdpi/ic_launcher.png"
                       )
      end
    end

    context "resources" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "resources", apk_name) }

      context "drawablePngIconOnly" do
        let(:apk_name) { "apks-21/drawablePngIconOnly.apk" }

        it do
          is_expected.to eq(
                           "hdpi" => "res/drawable-hdpi-v4/ic_launcher.png",
                           "mdpi" => "res/drawable-mdpi-v4/ic_launcher.png",
                           "xhdpi" => "res/drawable-xhdpi-v4/ic_launcher.png",
                           "xxhdpi" => "res/drawable-xxhdpi-v4/ic_launcher.png",
                           "xxxhdpi" => "res/drawable-xxxhdpi-v4/ic_launcher.png"
                         )
        end
      end

      context "mipmapPngIconOnly" do
        let(:apk_name) { "apks-21/mipmapPngIconOnly.apk" }

        it do
          is_expected.to eq(
                           "hdpi" => "res/mipmap-hdpi-v4/ic_launcher.png",
                           "mdpi" => "res/mipmap-mdpi-v4/ic_launcher.png",
                           "xhdpi" => "res/mipmap-xhdpi-v4/ic_launcher.png",
                           "xxhdpi" => "res/mipmap-xxhdpi-v4/ic_launcher.png",
                           "xxxhdpi" => "res/mipmap-xxxhdpi-v4/ic_launcher.png"
                         )
        end
      end

      context "pngInDrawable" do
        let(:apk_name) { "apks-21/pngInDrawable.apk" }

        it do
          is_expected.to match(
                           "(default)" => "res/drawable/ic_launcher.png"
                         )
        end
      end

      context "noIcon" do
        let(:apk_name) { "apks-21/noIcon.apk" }

        it { is_expected.to eq({}) }
      end

      context "adaptiveIconWithPng" do
        context "min sdk is 14" do
          let(:apk_name) { "apks-14/adaptiveIconWithPng.apk" }

          it do
            is_expected.to eq(
                             "anydpi-v26" => "res/mipmap-anydpi-v26/ic_launcher.xml",
                             "hdpi" => "res/mipmap-hdpi-v4/ic_launcher.png",
                             "mdpi" => "res/mipmap-mdpi-v4/ic_launcher.png",
                             "xhdpi" => "res/mipmap-xhdpi-v4/ic_launcher.png",
                             "xxhdpi" => "res/mipmap-xxhdpi-v4/ic_launcher.png",
                             "xxxhdpi" => "res/mipmap-xxxhdpi-v4/ic_launcher.png"
                           )
          end
        end

        context "min sdk is 26" do
          let(:apk_name) { "apks-26/adaptiveIconWithPng.apk" }

          it do
            is_expected.to eq(
                             "anydpi" => "res/mipmap-anydpi-v26/ic_launcher.xml",
                             "hdpi" => "res/mipmap-hdpi-v4/ic_launcher.png",
                             "mdpi" => "res/mipmap-mdpi-v4/ic_launcher.png",
                             "xhdpi" => "res/mipmap-xhdpi-v4/ic_launcher.png",
                             "xxhdpi" => "res/mipmap-xxhdpi-v4/ic_launcher.png",
                             "xxxhdpi" => "res/mipmap-xxxhdpi-v4/ic_launcher.png"
                           )
          end
        end
      end

      context "adaptiveIconWithRoundPng" do
        context "min sdk is 14" do
          let(:apk_name) { "apks-14/adaptiveIconWithRoundPng.apk" }

          it do
            is_expected.to eq(
                             "anydpi-v26" => "res/mipmap-anydpi-v26/ic_launcher.xml",
                             "hdpi" => "res/mipmap-hdpi-v4/ic_launcher.png",
                             "mdpi" => "res/mipmap-mdpi-v4/ic_launcher.png",
                             "xhdpi" => "res/mipmap-xhdpi-v4/ic_launcher.png",
                             "xxhdpi" => "res/mipmap-xxhdpi-v4/ic_launcher.png",
                             "xxxhdpi" => "res/mipmap-xxxhdpi-v4/ic_launcher.png"
                           )
          end
        end

        context "min sdk is 26" do
          let(:apk_name) { "apks-26/adaptiveIconWithRoundPng.apk" }

          it do
            is_expected.to eq(
                             "anydpi" => "res/mipmap-anydpi-v26/ic_launcher.xml",
                             "hdpi" => "res/mipmap-hdpi-v4/ic_launcher.png",
                             "mdpi" => "res/mipmap-mdpi-v4/ic_launcher.png",
                             "xhdpi" => "res/mipmap-xhdpi-v4/ic_launcher.png",
                             "xxhdpi" => "res/mipmap-xxhdpi-v4/ic_launcher.png",
                             "xxxhdpi" => "res/mipmap-xxxhdpi-v4/ic_launcher.png"
                           )
          end
        end
      end

      context "misconfiguredAdaptiveIcon" do
        context "min sdk is 14" do
          let(:apk_name) { "apks-14/misconfiguredAdaptiveIcon.apk" }

          it do
            is_expected.to match(
                             "anydpi-v26" => "res/mipmap-anydpi-v26/ic_launcher.xml"
                           )
          end
        end

        context "min sdk is 26" do
          let(:apk_name) { "apks-26/misconfiguredAdaptiveIcon.apk" }

          it do
            is_expected.to match(
                             "anydpi" => "res/mipmap-anydpi-v26/ic_launcher.xml"
                           )
          end
        end
      end

      context "vectorDrawableWithPng" do
        context "min sdk 14" do
          let(:apk_name) { "apks-14/vectorDrawableWithPng.apk" }

          it do
            is_expected.to eq(
                             "anydpi-v21" => "res/drawable-anydpi-v21/ic_launcher.xml",
                             "hdpi" => "res/drawable-hdpi-v4/ic_launcher.png",
                             "mdpi" => "res/drawable-mdpi-v4/ic_launcher.png",
                             "ldpi" => "res/drawable-ldpi-v4/ic_launcher.png",
                             "xhdpi" => "res/drawable-xhdpi-v4/ic_launcher.png",
                             "xxhdpi" => "res/drawable-xxhdpi-v4/ic_launcher.png",
                             "xxxhdpi" => "res/drawable-xxxhdpi-v4/ic_launcher.png"
                           )
          end
        end

        context "min sdk 21" do
          let(:apk_name) { "apks-21/vectorDrawableWithPng.apk" }

          it do
            is_expected.to eq(
                             "(default)" => "res/drawable/ic_launcher.xml",
                             "hdpi" => "res/drawable-hdpi-v4/ic_launcher.png",
                             "mdpi" => "res/drawable-mdpi-v4/ic_launcher.png",
                             "xhdpi" => "res/drawable-xhdpi-v4/ic_launcher.png",
                             "xxhdpi" => "res/drawable-xxhdpi-v4/ic_launcher.png",
                             "xxxhdpi" => "res/drawable-xxxhdpi-v4/ic_launcher.png"
                           )
          end
        end
      end

      context "vectorDrawableIconOnly" do
        let(:apk_name) { "apks-21/vectorDrawableIconOnly.apk" }

        it do
          is_expected.to eq(
                           "(default)" => "res/drawable/ic_launcher.xml"
                         )
        end
      end
    end

    context "new-resources" do
      let(:apk_filepath) { File.join(FIXTURE_DIR, "new-resources", apk_name) }

      context "drawablePngIconOnly" do
        let(:apk_name) { "apks-21/drawablePngIconOnly.apk" }

        it do
          is_expected.to match(
                           "hdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                           "mdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                           "xhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                           "xxhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                           "xxxhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z})
                         )
        end
      end

      context "mipmapPngIconOnly" do
        let(:apk_name) { "apks-21/mipmapPngIconOnly.apk" }

        it do
          is_expected.to match(
                           "hdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                           "mdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                           "xhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                           "xxhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                           "xxxhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z})
                         )
        end
      end

      context "pngInDrawable" do
        let(:apk_name) { "apks-21/pngInDrawable.apk" }

        it do
          is_expected.to match(
                           "(default)" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z})
                         )
        end
      end

      context "noIcon" do
        let(:apk_name) { "apks-21/noIcon.apk" }

        it { is_expected.to eq({}) }
      end

      context "adaptiveIconWithPng" do
        context "min sdk is 14" do
          let(:apk_name) { "apks-14/adaptiveIconWithPng.apk" }

          it do
            is_expected.to match(
                             "anydpi-v26" => match(%r{\Ares/[a-zA-Z0-9]{2}\.xml\z}),
                             "hdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "mdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "xhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "xxhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "xxxhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z})
                           )
          end
        end

        context "min sdk is 26" do
          let(:apk_name) { "apks-26/adaptiveIconWithPng.apk" }

          it do
            is_expected.to match(
                             "anydpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.xml\z}),
                             "hdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "mdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "xhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "xxhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "xxxhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z})
                           )
          end
        end
      end

      context "misconfiguredAdaptiveIcon" do
        context "min sdk is 14" do
          let(:apk_name) { "apks-14/misconfiguredAdaptiveIcon.apk" }

          it do
            is_expected.to match(
                             "anydpi-v26" => match(%r{\Ares/[a-zA-Z0-9]{2}\.xml\z})
                           )
          end
        end

        context "min sdk is 26" do
          let(:apk_name) { "apks-26/misconfiguredAdaptiveIcon.apk" }

          it do
            is_expected.to match(
                             "anydpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.xml\z})
                           )
          end
        end
      end

      context "vectorDrawableWithPng" do
        context "min sdk 14" do
          let(:apk_name) { "apks-14/vectorDrawableWithPng.apk" }

          it do
            is_expected.to match(
                             "anydpi-v21" => match(%r{\Ares/[a-zA-Z0-9]{2}\.xml\z}),
                             "hdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "mdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "ldpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "xhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "xxhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "xxxhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z})
                           )
          end
        end

        context "min sdk 21" do
          let(:apk_name) { "apks-21/vectorDrawableWithPng.apk" }

          it do
            is_expected.to match(
                             "(default)" => match(%r{\Ares/[a-zA-Z0-9]{2}\.xml\z}),
                             "hdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "mdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "xhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "xxhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z}),
                             "xxxhdpi" => match(%r{\Ares/[a-zA-Z0-9]{2}\.png\z})
                           )
          end
        end
      end

      context "vectorDrawableIconOnly" do
        let(:apk_name) { "apks-21/vectorDrawableIconOnly.apk" }

        it do
          is_expected.to match(
                           "(default)" => match(%r{\Ares/[a-zA-Z0-9]{2}\.xml\z})
                         )
        end
      end
    end
  end
end
