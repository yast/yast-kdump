#! /usr/bin/env rspec
require_relative "./test_helper"

Yast.import "Kdump"

describe "#use_fadump" do
  before do
    allow(Yast::Kdump).to receive(:fadump_supported?).and_return(supported)
  end

  context "if fadump is supported on this architecture" do
    let(:supported) { true }

    it "returns true when enabling fadump" do
      expect(Yast::Kdump.use_fadump(true)).to eq(true)
    end

    it "returns true when disabling fadump" do
      expect(Yast::Kdump.use_fadump(false)).to eq(true)
    end
  end

  context "if fadump is not supported on this architecture" do
    let(:supported) { false }

    it "returns false and show error popup when enabling fadump" do
      expect(Yast::Report).to receive(:Error)
      expect(Yast::Kdump.use_fadump(true)).to eq(false)
    end

    it "returns true when disabling fadump" do
      expect(Yast::Kdump.use_fadump(false)).to eq(true)
    end
  end
end

describe "#using_fadump?" do
  it "returns that fadump is in use if previously set" do
    allow(Yast::Kdump).to receive(:fadump_supported?).and_return(true)

    Yast::Kdump.use_fadump(true)
    expect(Yast::Kdump.using_fadump?).to eq(true)

    Yast::Kdump.use_fadump(false)
    expect(Yast::Kdump.using_fadump?).to eq(false)
  end
end

describe "#using_fadump_changed?" do
  it "returns false if use_fadump not changed" do
    Yast::Kdump.ReadKdumpSettings

    expect(Yast::Kdump.using_fadump_changed?).to eq(false)
  end

  it "returns true if use_fadump changed" do
    allow(Yast::Kdump).to receive(:fadump_supported?).and_return(true)
    Yast::Kdump.ReadKdumpSettings

    original_value = Yast::Kdump.using_fadump?
    Yast::Kdump.use_fadump(!original_value)

    expect(Yast::Kdump.using_fadump_changed?).to eq(true)
  end
end
