#!/usr/bin/env rspec

require_relative "../test_helper"
require_relative "../../src/lib/kdump/kdump_system"

Yast.import "Arch"

describe Yast::KdumpSystem do
  describe "#reported_memory" do
    it "returns the size in MiB" do
      allow(Yast::SCR).to receive(:Read).with(path(".probe.memory"))
        .and_return ["resource" => { "mem"      => [{ "active" => true, "length" => 12_465_651_712, "start" => 0 }],
                                     "phys_mem" => [{ "range"=>12_884_901_888 }] }]

      expect(subject.reported_memory).to eq 12_288
    end
  end

  describe "#supports_fadump?" do
    it "returns true on ppc64 architecture" do
      allow(Yast::Arch).to receive(:ppc64).and_return(true)
      expect(subject.supports_fadump?).to eq true
    end

    it "returns false on other architectures" do
      allow(Yast::Arch).to receive(:ppc64).and_return(false)
      expect(subject.supports_fadump?).to eq false
    end
  end

  describe "#supports_kdump?" do
    before do
      allow(Yast::Arch).to receive(:paravirtualized_xen_guest?).and_return xen_pv_domU
    end

    context "in a Xen PV DomU" do
      let(:xen_pv_domU) { true }

      it "returns false" do
        expect(subject.supports_kdump?).to eq false
      end
    end

    context "in a system not being a Xen PV DomU" do
      let(:xen_pv_domU) { false }

      it "returns true" do
        expect(subject.supports_kdump?).to eq true
      end
    end
  end
end
