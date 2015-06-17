#!/usr/bin/env rspec

require_relative "./test_helper"

Yast.import "Kdump"
Yast.import "SpaceCalculation"

describe Yast::Kdump do
  # allocated_memory is a string   in megabytes
  # total_memory     is an integer in megabytes
  describe "#ProposeAllocatedMemory" do
    context "when already proposed" do
      before(:each) do
        Yast::Kdump.allocated_memory = "42"
      end
      it "proposes the current value" do
        Yast::Kdump.ProposeAllocatedMemory
        expect(Yast::Kdump.allocated_memory).to eq "42"
      end
    end

    context "when not yet proposed" do
      before(:each) do
        Yast::Kdump.allocated_memory = "0"
      end

      context "when the proposal tool is not implemented yet" do
        before(:each) do
          allow(Yast::SCR).to receive(:Execute)
            .with(Yast::Path.new(".target.bash"), /^cp/).and_return(0)
          expect(Yast::SCR).to receive(:Execute)
            .with(Yast::Path.new(".target.bash_output"), /^kdumptool/)
            .and_return({"exit" => 1, "stdout" => "", "stderr" => "not there" })
        end

        it "proposes a positive integer" do
          Yast::Kdump.ProposeAllocatedMemory
          expect(Yast::Kdump.allocated_memory.to_i).to be > 0
        end
      end
    end
  end

  let(:partition_info) {[
     {"free"=>389318, "name"=>"/", "used"=>1487222},
     {"free"=>1974697, "name"=>"usr", "used"=>4227733},
     {"free"=>2974697, "name"=>"/var", "used"=>4227733},
     # this is the matching partition entry
     {"free"=>8974697, "name"=>"var/crash", "used"=>16},
     {"free"=>397697, "name"=>"var/crash/not-this", "used"=>455}
  ]}

  describe "#free_space_for_dump" do
    before do
      allow(Yast::SpaceCalculation).to receive(:GetPartitionInfo).and_return(partition_info)
      Yast::Kdump.KDUMP_SETTINGS["KDUMP_SAVEDIR"] = "file:///var/crash"
    end

    context "when dump location is local" do
      it "returns space on disk in bytes available for kernel dump" do
        # partition info counts in kB, we us bytes
        expect(Yast::Kdump.free_space_for_dump).to eq(8974697 * 1024)
      end
    end

    context "when dump location is not local" do
      it "returns 'nil'" do
        Yast::Kdump.KDUMP_SETTINGS["KDUMP_SAVEDIR"] = "nfs://server/export/var/log/dump"
        expect(Yast::Kdump.free_space_for_dump).to eq(nil)

        Yast::Kdump.KDUMP_SETTINGS["KDUMP_SAVEDIR"] = "ssh://user:password@host/var/log/dump"
        expect(Yast::Kdump.free_space_for_dump).to eq(nil)
      end
    end

    context "when empty partition info is available" do
      it "returns 'nil'" do
        allow(Yast::SpaceCalculation).to receive(:GetPartitionInfo).and_return([])
        expect(Yast::Kdump.free_space_for_dump).to eq(nil)
      end
    end

    context "when partition does not provide free space information" do
      it "returns 'nil'" do
        allow(Yast::SpaceCalculation).to receive(:GetPartitionInfo).and_return([{"free"=>nil, "name"=>"var/crash"}])
        expect(Yast::Kdump.free_space_for_dump).to eq(nil)

        allow(Yast::SpaceCalculation).to receive(:GetPartitionInfo).and_return([{"name"=>"var/crash"}])
        expect(Yast::Kdump.free_space_for_dump).to eq(nil)
      end
    end
  end

  # in MB
  let(:total_memory_size) { 8 * 1024 ** 2 }

  describe "#space_requested_for_dump" do
    it "" do
      allow(Yast::Kdump).to receive(:total_memory).and_return(total_memory_size)

      expect(Yast::Kdump.space_requested_for_dump).to eq(total_memory_size * 1024**2 + 4 * 1024**3)
    end
  end

  describe "#proposal_warnig" do
    before do
      allow(Yast::Kdump).to receive(:space_requested_for_dump).and_return(4 * 1024**4)
      Yast::Kdump.instance_variable_set("@add_crashkernel_param", true)
    end

    context "when kdump is not enabled" do
      it "returns empty hash" do
        Yast::Kdump.instance_variable_set("@add_crashkernel_param", false)

        warning = Yast::Kdump.proposal_warnig
        expect(warning).to eq({})
      end
    end

    context "when free space is smaller than requested" do
      it "returns hash with warning and warning_level keys" do
        allow(Yast::Kdump).to receive(:free_space_for_dump).and_return(3.89 * 1024**4)

        warning = Yast::Kdump.proposal_warnig
        expect(warning["warning"]).to match(/not enough free space/)
        expect(warning["warning_level"]).not_to eq(nil)
      end
    end

    context "when free space is bigger or equal to requested size" do
      it "returns empty hash" do
        allow(Yast::Kdump).to receive(:free_space_for_dump).and_return(120 * 1024**4)

        warning = Yast::Kdump.proposal_warnig
        expect(warning).to eq({})
      end
    end
  end
end
