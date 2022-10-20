# frozen_string_literal: true

describe AndroidApk::ResourceFinder do
  let(:resource_finder) { AndroidApk::ResourceFinder.new(delegatee: delegatee) }
  let(:delegatee) { double(:finder) }

  before do
    allow(delegatee).to receive(:resolve_icons_in_arsc).and_return(nil)
  end

  describe "#resolve_icons_in_arsc" do
    subject { resource_finder.resolve_icons_in_arsc(apk_filepath: 'apk_filepath', default_icon_path: default_icon_path) }

    context 'when default_icon_path is nil' do
      let(:default_icon_path) { nil }

      it "delegates successfully and returns a hash" do
        is_expected.to be_empty
        expect(delegatee).to have_received(:resolve_icons_in_arsc).with(apk_filepath: 'apk_filepath', default_icon_path: default_icon_path)
      end
    end

    context 'when default_icon_path is empty' do
      let(:default_icon_path) { nil }

      it "delegates successfully and returns a hash" do
        is_expected.to be_empty
        expect(delegatee).to have_received(:resolve_icons_in_arsc).with(apk_filepath: 'apk_filepath', default_icon_path: default_icon_path)
      end
    end
  end
end
