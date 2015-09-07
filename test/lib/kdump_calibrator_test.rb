#!/usr/bin/env rspec

require_relative "../test_helper"
require_relative "../../src/lib/kdump/kdump_calibrator"

Yast.import "Arch"

describe Yast::KdumpCalibrator do
  subject { described_class.new(configfile) }
  KDUMPTOOL_OK = { "exit" => 0, "stdout" => "MinLow: 72\nMaxLow: 896\nMinHigh: 1024\nMaxHigh: 4096\n" }
  KDUMPTOOL_ERROR = { "exit" => 1, "stdout" => "" }

  let(:configfile) { "/var/lib/YaST2/kdump.conf" }
  let(:x86_64) { true }
  let(:kdumptool_output) { KDUMPTOOL_OK }

  before do
    allow(Yast::Arch).to receive(:x86_64).and_return(x86_64)
    allow(Yast::SCR).to receive(:Execute)
      .with(Yast::Path.new(".target.bash_output"), anything).and_return(kdumptool_output)
  end

  describe "total_memory" do
    it "returns total memory as reported by SCR" do
      allow(Yast::SCR).to receive(:Read).with(path(".probe.memory"))
        .and_return([
          {"class_id" => 257, "model" => "Main Memory",
           "resource" => { "mem" => [{ "active" => true, "length" => 4294967296, "start"=>0 } ],
                           "phys_mem" => [{ "range" => 4294967296 }]}, "sub_class_id"=>2 }])

      expect(subject.total_memory).to eq(4096)
    end
  end

  describe "#min_low" do
    context "when kdumptool succeeds" do
      it "returns the value found by kdumptool" do
        expect(subject.min_low).to eq(72)
      end
    end

    context "when kdumptool does not succeed" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      it "returns 72" do
        expect(subject.min_low).to eq(72)
      end
    end
  end

  context "#max_low" do
    context "when kdumptool succeeds" do
      it "returns the value found in kdumptool" do
        expect(subject.min_low).to eq(72)
      end
    end

    context "when kdumptool does not succeed" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      before do
        allow(subject).to receive(:total_memory).and_return(total_memory)
      end

      context "when available memory is more than 896" do
        let(:total_memory) { 4096 }

        it "returns 896" do
          expect(subject.max_low).to eq(896)
        end
      end

      context "when available memory is less than 896" do
        let(:total_memory) { 784 }

        it "returns system memory" do # all system memory?
          expect(subject.max_low).to eq(total_memory)
        end
      end

      context "when high memory is not supported" do
        let(:total_memory) { 1024 }
        let(:x86_64) { false }

        it "returns system memory" do
          expect(subject.max_low).to eq(total_memory)
        end
      end
    end
  end

  describe "#min_high" do
    let(:x86_64) { true }

    context "when kdumptool succeeds" do
      it "returns the value found by kdumptool" do
        expect(subject.min_high).to eq(1024)
      end
    end

    context "when kdumptool fails" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      it "returns 0" do
        expect(subject.min_high).to eq(0)
      end
    end

    context "when high memory is not supported" do
      let(:x86_64) { false }

      it "returns 0" do
        expect(subject.min_high).to eq(0)
      end
    end
  end

  describe "#max_high" do
    let(:x86_64) { true }

    context "when kdumptool succeeds" do
      it "returns the value found by kdumptool" do
        expect(subject.max_high).to eq(4096)
      end
    end

    context "when kdumptool fails" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      it "returns total_memory - 896" do
        expect(subject.max_high).to eq(0)
      end
    end

    context "when high memory is not supported" do
      let(:x86_64) { false }

      it "returns 0" do
        expect(subject.max_high).to eq(0)
      end
    end
  end

  describe "#high_memory_supported?" do
    context "when architecture is x86_64" do
      it "returns true" do
        expect(subject.high_memory_supported?).to eq(true)
      end
    end

    context "when architecture is not x86_64" do
      let(:x86_64) { false }

      it "returns false" do
        expect(subject.high_memory_supported?).to eq(false)
      end
    end
  end
end
