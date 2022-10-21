# frozen_string_literal: true

describe AndroidApk::Aapt2::ResourceFinder do
  describe "#collect_in_section" do
    let(:yielded) { [] }

    let(:collect_in_section) do
      AndroidApk::Aapt2::ResourceFinder.collect_in_section(lines: lines, pivot_index: pivot_index) do |dpi, path|
        yielded << [dpi, path]
      end
    end

    before do
      collect_in_section
    end

    context "on the simplest case" do
      let(:lines) do
        [
          "brabrabra",
          "  resource <address> mipmap/block1",
          "    (mdpi-v4) (file) res/x0.png type=PNG",
          "    (hdpi-v4) (file) res/x1.png type=PNG",
          "    (xhdpi-v4) (file) res/x2.png type=PNG",
          "    (xxhdpi-v4) (file) res/x3.png type=PNG",
          "  resource <address> mipmap/block2",
        ]
      end

      context "if pivot_index is the first position" do
        let(:pivot_index) { 2 }

        it do
          expect(yielded).to eq([
                                  %w(mdpi-v4 res/x0.png),
                                  %w(hdpi-v4 res/x1.png),
                                  %w(xhdpi-v4 res/x2.png),
                                  %w(xxhdpi-v4 res/x3.png)
                                ])
        end
      end

      context "if pivot_index is the middle position" do
        let(:pivot_index) { 3 }

        it do
          expect(yielded).to eq([
                                  %w(hdpi-v4 res/x1.png),
                                  %w(mdpi-v4 res/x0.png),
                                  %w(xhdpi-v4 res/x2.png),
                                  %w(xxhdpi-v4 res/x3.png)
                                ])
        end
      end

      context "if pivot_index is the last position" do
        let(:pivot_index) { 5 }

        it do
          expect(yielded).to eq([
                                  %w(xxhdpi-v4 res/x3.png),
                                  %w(xhdpi-v4 res/x2.png),
                                  %w(hdpi-v4 res/x1.png),
                                  %w(mdpi-v4 res/x0.png)
                                ])
        end
      end
    end

    context "on the last segment case" do
      let(:lines) do
        [
          "brabrabra",
          "  resource <address> mipmap/block1",
          "    (mdpi-v4) (file) res/x0.png type=PNG",
          "    (hdpi-v4) (file) res/x1.png type=PNG",
          "    (xhdpi-v4) (file) res/x2.png type=PNG",
          "    (xxhdpi-v4) (file) res/x3.png type=PNG"
        ]
      end

      context "if pivot_index is the first position" do
        let(:pivot_index) { 2 }

        it do
          expect(yielded).to eq([
                                  %w(mdpi-v4 res/x0.png),
                                  %w(hdpi-v4 res/x1.png),
                                  %w(xhdpi-v4 res/x2.png),
                                  %w(xxhdpi-v4 res/x3.png)
                                ])
        end
      end

      context "if pivot_index is the middle position" do
        let(:pivot_index) { 3 }

        it do
          expect(yielded).to eq([
                                  %w(hdpi-v4 res/x1.png),
                                  %w(mdpi-v4 res/x0.png),
                                  %w(xhdpi-v4 res/x2.png),
                                  %w(xxhdpi-v4 res/x3.png)
                                ])
        end
      end

      context "if pivot_index is the last position" do
        let(:pivot_index) { 5 }

        it do
          expect(yielded).to eq([
                                  %w(xxhdpi-v4 res/x3.png),
                                  %w(xhdpi-v4 res/x2.png),
                                  %w(hdpi-v4 res/x1.png),
                                  %w(mdpi-v4 res/x0.png)
                                ])
        end
      end
    end

    context "on the odd case" do
      let(:lines) do
        [
          "brabrabra",
          "  resource <address> mipmap/block1",
          "    (mdpi-v4) (file) res/x0.png type=PNG",
          "    (hdpi-v4) (file) res/x1.png type=PNG",
          "    (xhdpi-v4) (file) res/x2.png type=PNG"
        ]
      end

      context "if pivot_index is the first position" do
        let(:pivot_index) { 2 }

        it do
          expect(yielded).to eq([
                                  %w(mdpi-v4 res/x0.png),
                                  %w(hdpi-v4 res/x1.png),
                                  %w(xhdpi-v4 res/x2.png)
                                ])
        end
      end

      context "if pivot_index is the middle position" do
        let(:pivot_index) { 3 }

        it do
          expect(yielded).to eq([
                                  %w(hdpi-v4 res/x1.png),
                                  %w(mdpi-v4 res/x0.png),
                                  %w(xhdpi-v4 res/x2.png)
                                ])
        end
      end

      context "if pivot_index is the last position" do
        let(:pivot_index) { 4 }

        it do
          expect(yielded).to eq([
                                  %w(xhdpi-v4 res/x2.png),
                                  %w(hdpi-v4 res/x1.png),
                                  %w(mdpi-v4 res/x0.png)
                                ])
        end
      end
    end

    context "on the (default) case" do
      let(:lines) do
        [
          "brabrabra",
          "  resource <address> mipmap/block1",
          "    () (file) res/x0.png type=PNG"
        ]
      end

      let(:pivot_index) { 2 }

      it do
        expect(yielded).to eq([
                                %w[(default) res/x0.png]
                              ])
      end
    end
  end
end
