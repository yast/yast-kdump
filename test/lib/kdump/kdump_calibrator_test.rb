#!/usr/bin/env rspec

require_relative "../../test_helper"
require "kdump/kdump_calibrator"

Yast.import "Arch"

describe Yast::KdumpCalibrator do
  subject { described_class.new(configfile) }
  KDUMPTOOL_OK = {
    "exit"   => 0,
    "stdout" => "Low: 108\nMinLow: 32\nMaxLow: 712\n"\
                "High: 2048\nMinHigh: 1024\nMaxHigh: 4096\n"\
                "Fadump: 0\nMinFadump: 0\nMaxFadump: 0\nTotal: 16079\n"
  }.freeze
  KDUMPTOOL_ERROR = { "exit" => 1, "stdout" => "" }.freeze

  let(:configfile) { "/var/lib/YaST2/kdump.conf" }
  let(:x86_64) { true }
  let(:ppc64) { false }
  let(:kdumptool_output) { KDUMPTOOL_OK }

  before do
    allow(Yast::Arch).to receive(:x86_64).and_return(x86_64)
    allow(Yast::Arch).to receive(:ppc64).and_return(ppc64)
    allow(Yast::SCR).to receive(:Execute)
      .with(Yast::Path.new(".target.bash_output"), anything).and_return(kdumptool_output)
    allow(Yast::SCR).to receive(:Read).with(path(".probe.memory"))
      .and_return([
                    { "class_id" => 257, "model" => "Main Memory",
                     "resource" => { "mem"      => [{ "active" => true, "length" => 4294967296, "start" => 0 }],
                                     "phys_mem" => [{ "range" => 4294967296 }] }, "sub_class_id" => 2 }
                  ])
  end

  describe "#total_memory" do
    context "when kdumptool succeeds" do
      it "returns the value found in kdumptool" do
        expect(subject.total_memory).to eq(16079)
      end
    end

    context "when kdumptool fails" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      it "returns total memory as reported by SCR" do
        expect(subject.total_memory).to eq(4096)
      end
    end
  end

  describe "#min_low" do
    context "when kdumptool succeeds" do
      it "returns the value found by kdumptool" do
        expect(subject.min_low).to eq(32)
      end
    end

    context "when kdumptool does not succeed" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      it "returns 0" do
        expect(subject.min_low).to eq(0)
      end
    end
  end

  describe "#default_low" do
    context "when kdumptool succeeds" do
      it "returns the value found by kdumptool" do
        expect(subject.default_low).to eq(108)
      end
    end

    context "when kdumptool does not succeed" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      it "returns 0" do
        expect(subject.default_low).to eq(0)
      end
    end
  end

  context "#max_low" do
    context "when kdumptool succeeds" do
      it "returns the value found in kdumptool" do
        expect(subject.max_low).to eq(712)
      end
    end

    context "when kdumptool fails" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }
      let(:total_memory) { 4096 }

      before do
        allow(subject).to receive(:total_memory).and_return(total_memory)
      end

      it "returns total_memory" do
        expect(subject.max_low).to eq(4096)
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
  end

  describe "#default_high" do
    let(:x86_64) { true }

    context "when kdumptool succeeds" do
      it "returns the value found by kdumptool" do
        expect(subject.default_high).to eq(2048)
      end
    end

    context "when kdumptool fails" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      it "returns 0 (the minimum fallback)" do
        expect(subject.default_high).to eq(0)
      end
    end
  end

  describe "#max_high" do
    context "when kdumptool succeeds" do
      it "returns the value found by kdumptool" do
        expect(subject.max_high).to eq(4096)
      end
    end

    context "when kdumptool fails" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      context "when high memory is supported" do
        let(:x86_64) { true }

        it "returns total_memory" do
          allow(subject).to receive(:total_memory).and_return(4096)

          expect(subject.max_high).to eq(4096)
        end
      end

      context "when high memory is not supported" do
        let(:x86_64) { false }

        it "returns 0" do
          expect(subject.max_high).to eq(0)
        end
      end
    end
  end

  describe "#high_memory_supported?" do
    subject(:supported) { described_class.new(configfile).high_memory_supported? }

    context "when kdumptool succeeds" do
      context "if kdumptool allows high memory" do
        it "returns true" do
          expect(supported).to eq(true)
        end
      end

      context "if kdumptool returns 0 for high memory" do
        let(:kdumptool_output) do
          {
            "exit"   => 0,
            "stdout" => "Low: 108\nMinLow: 32\nMaxLow: 712\n"\
                        "High:0\nMinHigh: 0\nMaxHigh: 0\nTotal: 2048"
          }
        end

        it "returns false" do
          expect(supported).to eq(false)
        end
      end
    end

    context "when kdumptool fails" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      context "when architecture is x86_64" do
        it "returns true" do
          expect(supported).to eq(true)
        end
      end

      context "when architecture is not x86_64" do
        let(:x86_64) { false }

        it "returns false" do
          expect(supported).to eq(false)
        end
      end
    end
  end

  describe "#min_fadump" do
    context "when kdumptool succeeds" do
      let(:kdumptool_output) do
        {
          "exit"   => 0,
          "stdout" => "Low: 108\nMinLow: 32\nMaxLow: 712\n"\
                      "High: 2048\nMinHigh: 1024\nMaxHigh: 4096\n"\
                      "Fadump: 256\nMinFadump: 128\nMaxFadump: 8192\nTotal: 16079\n"
        }
      end

      it "returns the value found by kdumptool" do
        expect(subject.min_fadump).to eq(128)
      end
    end

    context "when kdumptool fails" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      it "returns 0" do
        expect(subject.min_fadump).to eq(0)
      end
    end
  end

  describe "#default_fadump" do
    context "when kdumptool succeeds" do
      let(:kdumptool_output) do
        {
          "exit"   => 0,
          "stdout" => "Low: 108\nMinLow: 32\nMaxLow: 712\n"\
                      "High: 2048\nMinHigh: 1024\nMaxHigh: 4096\n"\
                      "Fadump: 256\nMinFadump: 128\nMaxFadump: 8192\nTotal: 16079\n"
        }
      end

      it "returns the value found by kdumptool" do
        expect(subject.default_fadump).to eq(256)
      end
    end

    context "when kdumptool fails" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      it "returns 0 (the minimum fallback)" do
        expect(subject.default_fadump).to eq(0)
      end
    end
  end

  describe "#max_fadump" do
    context "when kdumptool succeeds" do
      let(:kdumptool_output) do
        {
          "exit"   => 0,
          "stdout" => "Low: 108\nMinLow: 32\nMaxLow: 712\n"\
                      "High: 2048\nMinHigh: 1024\nMaxHigh: 4096\n"\
                      "Fadump: 256\nMinFadump: 128\nMaxFadump: 8192\nTotal: 16079\n"
        }
      end

      it "returns the value found by kdumptool" do
        expect(subject.max_fadump).to eq(8192)
      end
    end

    context "when kdumptool fails" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      context "when fadump memory is supported" do
        let(:ppc64) { true }

        it "returns total_memory" do
          allow(subject).to receive(:total_memory).and_return(4096)

          expect(subject.max_fadump).to eq(4096)
        end
      end

      context "when fadump memory is not supported" do
        let(:ppc64) { false }

        it "returns 0" do
          expect(subject.max_fadump).to eq(0)
        end
      end
    end
  end

  describe "#fadump_supported?" do
    subject(:supported) { described_class.new(configfile).fadump_supported? }

    context "when kdumptool succeeds" do
      context "if kdumptool allows fadump memory" do
        let(:kdumptool_output) do
          {
            "exit"   => 0,
            "stdout" => "Low: 108\nMinLow: 32\nMaxLow: 712\n"\
                        "High: 2048\nMinHigh: 1024\nMaxHigh: 4096\n"\
                        "Fadump: 256\nMinFadump: 128\nMaxFadump: 8192\nTotal: 16079\n"
          }
        end

        it "returns true" do
          expect(supported).to eq(true)
        end
      end

      context "if kdumptool returns 0 for fadump memory" do
        it "returns false" do
          expect(supported).to eq(false)
        end
      end
    end

    context "when kdumptool fails" do
      let(:kdumptool_output) { KDUMPTOOL_ERROR }

      context "when architecture is ppc64" do
        let(:ppc64) { true }

        it "returns true" do
          expect(supported).to eq(true)
        end
      end

      context "when architecture is not ppc64" do
        let(:ppc64) { false }

        it "returns false" do
          expect(supported).to eq(false)
        end
      end
    end
  end
end
