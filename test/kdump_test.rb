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

  let(:partition_info) do
    [
      {"free"=>389318, "name"=>"/", "used"=>1487222},
      {"free"=>1974697, "name"=>"usr", "used"=>4227733},
      {"free"=>2974697, "name"=>"/var", "used"=>4227733},
      # this is the matching partition entry
      {"free"=>8974697, "name"=>"var/crash", "used"=>16},
      {"free"=>397697, "name"=>"var/crash/not-this", "used"=>455}
    ]
  end

  let(:not_exactly_matching_partition_info) do
    [
      {"free"=>8888888, "name"=>"/"},
      {"free" => 1, "name" => "var/some"},
      {"free"=>5555555, "name"=>"somewhere/d"},
      {"free"=>6666666, "name"=>"somewhere/deep"}
    ]
  end

  describe "#free_space_for_dump_b" do
    before do
      allow(Yast::SpaceCalculation).to receive(:GetPartitionInfo).and_return(partition_info)
      Yast::Kdump.KDUMP_SETTINGS["KDUMP_SAVEDIR"] = "file:///var/crash"
    end

    context "when dump location is local" do
      it "returns space on disk in bytes available for kernel dump" do
        # partition info counts in kB, we us bytes
        expect(Yast::Kdump.free_space_for_dump_b).to eq(8974697 * 1024)
      end
    end

    context "when dump location is not local" do
      it "returns 'nil'" do
        Yast::Kdump.KDUMP_SETTINGS["KDUMP_SAVEDIR"] = "nfs://server/export/var/log/dump"
        expect(Yast::Kdump.free_space_for_dump_b).to eq(nil)

        Yast::Kdump.KDUMP_SETTINGS["KDUMP_SAVEDIR"] = "ssh://user:password@host/var/log/dump"
        expect(Yast::Kdump.free_space_for_dump_b).to eq(nil)
      end
    end

    context "when empty partition info is available" do
      it "returns 'nil'" do
        allow(Yast::SpaceCalculation).to receive(:GetPartitionInfo).and_return([])
        expect(Yast::Kdump.free_space_for_dump_b).to eq(nil)
      end
    end

    context "when partition does not provide free space information" do
      it "returns 'nil'" do
        allow(Yast::SpaceCalculation).to receive(:GetPartitionInfo).and_return([{"free"=>nil, "name"=>"var/crash"}])
        expect(Yast::Kdump.free_space_for_dump_b).to eq(nil)

        allow(Yast::SpaceCalculation).to receive(:GetPartitionInfo).and_return([{"name"=>"var/crash"}])
        expect(Yast::Kdump.free_space_for_dump_b).to eq(nil)
      end
    end

    context "when partition info does not exactly match directory for dump" do
      it "returns space on disk (in mountpoint above) in bytes available for kernel dump" do
        Yast::Kdump.KDUMP_SETTINGS["KDUMP_SAVEDIR"] = "file:///var/crash"
        allow(Yast::SpaceCalculation).to receive(:GetPartitionInfo).and_return(not_exactly_matching_partition_info)
        expect(Yast::Kdump.free_space_for_dump_b).to eq(8888888 * 1024)

        Yast::Kdump.KDUMP_SETTINGS["KDUMP_SAVEDIR"] = "file:///somewhere/deep/in/filesystem/"
        allow(Yast::SpaceCalculation).to receive(:GetPartitionInfo).and_return(not_exactly_matching_partition_info)
        expect(Yast::Kdump.free_space_for_dump_b).to eq(6666666 * 1024)
      end
    end
  end

  # in MB!
  let(:total_memory_size_mb) { 8 * 1024 }

  describe "#space_requested_for_dump_b" do
    it "returns space in bytes requested for kernel dump" do
      allow(Yast::Kdump).to receive(:total_memory).and_return(total_memory_size_mb)

      expect(Yast::Kdump.space_requested_for_dump_b).to eq(total_memory_size_mb * 1024**2 + 4 * 1024**3)
    end
  end

  describe "#proposal_warning" do
    before do
      allow(Yast::Kdump).to receive(:space_requested_for_dump_b).and_return(4 * 1024**3)
      Yast::Kdump.instance_variable_set("@add_crashkernel_param", true)
    end

    context "when kdump is not enabled" do
      it "returns empty hash" do
        Yast::Kdump.instance_variable_set("@add_crashkernel_param", false)

        warning = Yast::Kdump.proposal_warning
        expect(warning).to eq({})
      end
    end

    context "when free space is smaller than requested" do
      it "returns hash with warning and warning_level keys" do
        allow(Yast::Kdump).to receive(:free_space_for_dump_b).and_return(3978 * 1024**2)

        warning = Yast::Kdump.proposal_warning
        expect(warning["warning"]).to match(/There might not be enough free space.*only.*are available/)
        expect(warning["warning_level"]).not_to eq(nil)
      end
    end

    context "when free space is nearly as big as reqeuested, but still smaller" do
      it "returns hash with warning and warning_level keys" do
        allow(Yast::Kdump).to receive(:free_space_for_dump_b).and_return(Yast::Kdump.space_requested_for_dump_b - 30 * 1024**2)

        warning = Yast::Kdump.proposal_warning
        expect(warning["warning"]).to match(/There might not be enough free space.*additional.*are missing/)
        expect(warning["warning_level"]).not_to eq(nil)
      end
    end

    context "when free space is bigger or equal to requested size" do
      it "returns empty hash" do
        allow(Yast::Kdump).to receive(:free_space_for_dump_b).and_return(120 * 1024**3)

        warning = Yast::Kdump.proposal_warning
        expect(warning).to eq({})
      end
    end
  end
end
