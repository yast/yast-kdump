#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Kdump"
Yast.import "Arch"

describe "#fadump_supported?" do
  it "returns that fadump is supported on ppc64 architecture" do
    Yast::Arch.stub(:ppc64).and_return(true)
    expect(Yast::Kdump.fadump_supported?).to be_true
  end

  it "return that fadump is not supported on other architectures" do
    Yast::Arch.stub(:ppc64).and_return(false)
    expect(Yast::Kdump.fadump_supported?).to be_false
  end
end

describe "#use_fadump" do
  it "returns true if fadump is supported on this architecture" do
    Yast::Kdump.stub(:fadump_supported?).and_return(true)
    expect(Yast::Kdump.use_fadump(true)).to be_true
    expect(Yast::Kdump.use_fadump(false)).to be_true
  end

  it "returns false if adjusting to use fadump and it's not supported on this architecture" do
    Yast::Kdump.stub(:fadump_supported?).and_return(false)
    expect(Yast::Kdump.use_fadump(true)).to be_false
  end

  it "returns true if adjusting not to use fadump independently on the current architecture" do
    Yast::Kdump.stub(:fadump_supported?).and_return(true)
    expect(Yast::Kdump.use_fadump(false)).to be_true

    Yast::Kdump.stub(:fadump_supported?).and_return(false)
    expect(Yast::Kdump.use_fadump(false)).to be_true
  end
end

describe "#using_fadump?" do
 it "returns that fadump is in use if previously set" do
   Yast::Kdump.stub(:fadump_supported?).and_return(true)

   Yast::Kdump.use_fadump(true)
   expect(Yast::Kdump.using_fadump?).to be_true

   Yast::Kdump.use_fadump(false)
   expect(Yast::Kdump.using_fadump?).to be_false
 end
end

describe "#using_fadump_changed?" do
  it "returns false if use_fadump not changed" do
    Yast::Kdump.ReadKdumpSettings

    expect(Yast::Kdump.using_fadump_changed?).to be_false
  end

  it "returns true if use_fadump changed" do
    Yast::Kdump.ReadKdumpSettings

    Yast::Kdump.stub(:fadump_supported?).and_return(true)
    original_value = Yast::Kdump.using_fadump?
    Yast::Kdump.use_fadump(! original_value)

    expect(Yast::Kdump.using_fadump_changed?).to be_true
  end
end
