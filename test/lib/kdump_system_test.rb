#!/usr/bin/env rspec

require_relative "../test_helper"
require_relative "../../src/lib/kdump/kdump_system"

describe Yast::KdumpSystem do
  describe "#reported_memory" do
    it "returns the size in MiB" do
      allow(Yast::SCR).to receive(:Read).with(path(".probe.memory"))
        .and_return ["resource"=>{"mem"=>[{"active"=>true, "length"=>12465651712, "start"=>0}],
                                  "phys_mem"=>[{"range"=>12884901888}]}]

      expect(subject.reported_memory).to eq 12288
    end
  end

  describe "#supports_kdump?" do
    # Directory with the simulated systems to chroot into
    let(:roots_dir) { File.expand_path("../../systems", __FILE__) }

    around { |example| change_scr_root(File.join(roots_dir, root), &example) }

    context "in a non-Xen system" do
      let(:root) { "non-xen" }

      it "returns true" do
        expect(subject.supports_kdump?).to eq true
      end
    end

    context "in a Xen DomU" do
      let(:root) { "domU" }

      it "returns false" do
        expect(subject.supports_kdump?).to eq false
      end
    end

    context "in a Xen Dom0" do
      let(:root) { "dom0" }

      it "returns true" do
        expect(subject.supports_kdump?).to eq true
      end
    end
  end
end
