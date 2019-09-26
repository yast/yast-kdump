#!/usr/bin/env rspec

require_relative "./test_helper"

require "kdump/clients/auto"

describe Y2Kdump::Clients::Auto do
  describe "#import" do
    it "imports given hash" do
      expect(Yast::Kdump).to receive(:Import).with({})
      subject.import({})
    end
  end

  describe "#export" do
    it "returns hash" do
      expect(subject.export).to be_a ::Hash
    end
  end

  describe "#summary" do
    it "returns a string" do
      expect(subject.summary).to be_a ::String
    end
  end

  describe "#modified" do
    it "sets modified flag" do
      subject.modified
      expect(subject.modified?).to eq true
    end
  end

  describe "#reset" do
    it "import empty data" do
      expect(Yast::Kdump).to receive(:Import).with({})
      subject.reset
    end
  end

  describe "#read" do
    it "reads system kdump settings" do
      expect(Yast::Kdump).to receive(:Read)
      subject.read
    end
  end

  describe "#write" do
    it "writes settings to system" do
      expect(Yast::Kdump).to receive(:Write)
      subject.write
    end
  end

  describe "#packages" do
    before do
      allow(Yast::Kdump).to receive(:add_crashkernel_param).and_return(enabled)
    end

    context "kdump is enabled" do
      let(:enabled) { true }

      it "returns list of packages to install" do
        expect(subject.packages).to eq("install" => ["kexec-tools", "kdump"], "remove" => [])
      end
    end

    context "kdump is disabled" do
      let(:enabled) { false }

      it "returns empty list" do
        expect(subject.packages).to eq({})
      end
    end
  end
end
