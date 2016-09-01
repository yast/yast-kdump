#!/usr/bin/env rspec

require_relative "./test_helper"

Yast.import "Kdump"
Yast.import "Mode"
Yast.import "Bootloader"
Yast.import "Service"
Yast.import "Popup"
Yast.import "SpaceCalculation"
Yast.import "Arch"

describe Yast::Kdump do
  before do
    Yast::Kdump.reset
  end

  # allocated_memory is a hash, values are strings in megabytes
  # total_memory     is an integer in megabytes
  describe "#ProposeAllocatedMemory" do
    let(:proposed_memory) { Yast::Kdump.allocated_memory }

    context "when already proposed" do
      before(:each) do
        Yast::Kdump.allocated_memory = { low: "42", high: "666" }
      end

      it "proposes the current value" do
        Yast::Kdump.ProposeAllocatedMemory
        expect(proposed_memory).to eq(low: "42", high: "666")
      end
    end

    context "when not yet proposed" do
      before(:each) do
        Yast::Kdump.allocated_memory = {}
      end

      it "proposes the default values suggested by the calibrator" do
        allow(Yast::Kdump.calibrator).to receive(:default_low).and_return 11
        allow(Yast::Kdump.calibrator).to receive(:default_high).and_return 22

        Yast::Kdump.ProposeAllocatedMemory
        expect(proposed_memory).to eq(low: "11", high: "22")
      end
    end
  end

  describe "#ProposeCrashkernelParam" do
    before do
      allow(Yast::Kdump).to receive(:total_memory).and_return 1024
      allow(Yast::Arch).to receive(:aarch64).and_return false
    end

    context "while running on machine with less than 1024 MB memory" do
      it "proposes kdump to be disabled" do
        allow(Yast::Kdump).to receive(:total_memory).and_return 1023

        expect(Yast::Kdump.ProposeCrashkernelParam).to eq false
      end
    end

    context "while running on ARM64" do
      it "proposes kdump to be disabled" do
        allow(Yast::Arch).to receive(:aarch64).and_return true

        expect(Yast::Kdump.ProposeCrashkernelParam).to eq false
      end
    end

    context "otherwise" do
      it "always proposes kdump to be enabled" do
        expect(Yast::Kdump.ProposeCrashkernelParam).to eq true
      end
    end
  end

  let(:partition_info) do
    [
      { "free" => 389318, "name" => "/", "used" => 1487222 },
      { "free" => 1974697, "name" => "usr", "used" => 4227733 },
      { "free" => 2974697, "name" => "/var", "used" => 4227733 },
      # this is the matching partition entry
      { "free" => 8974697, "name" => "var/crash", "used" => 16 },
      { "free" => 397697, "name" => "var/crash/not-this", "used" => 455 }
    ]
  end

  let(:not_exactly_matching_partition_info) do
    [
      { "free" => 8888888, "name" => "/" },
      { "free" => 1, "name" => "var/some" },
      { "free" => 5555555, "name" => "somewhere/d" },
      { "free" => 6666666, "name" => "somewhere/deep" }
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
        allow(Yast::SpaceCalculation).to receive(:GetPartitionInfo).and_return([{ "free" => nil, "name" => "var/crash" }])
        expect(Yast::Kdump.free_space_for_dump_b).to eq(nil)

        allow(Yast::SpaceCalculation).to receive(:GetPartitionInfo).and_return([{ "name" => "var/crash" }])
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

    context "when free space is bigger or equal to requested size" do
      it "returns empty hash" do
        allow(Yast::Kdump).to receive(:free_space_for_dump_b).and_return(120 * 1024**3)

        warning = Yast::Kdump.proposal_warning
        expect(warning).to eq({})
      end
    end
  end

  describe ".ReadKdumpKernelParam" do
    before do
      allow(Yast::Bootloader).to receive(:kernel_param).and_return kernel_param
      Yast::Kdump.ReadKdumpKernelParam
    end

    context "when the param is not present" do
      let(:kernel_param) { :missing }

      it "reports param as not found" do
        expect(Yast::Kdump.crashkernel_param).to eq false
      end

      it "does not find several ranges" do
        expect(Yast::Kdump.crashkernel_list_ranges).to eq false
      end

      it "does not schedule writing on the param" do
        expect(Yast::Kdump.add_crashkernel_param).to eq false
      end
    end

    context "when the param is set to true" do
      let(:kernel_param) { :present }

      it "reports presence of the param" do
        expect(Yast::Kdump.crashkernel_param).to eq true
      end

      it "schedules the writing on the param" do
        expect(Yast::Kdump.add_crashkernel_param).to eq true
      end

      it "does not find several ranges" do
        expect(Yast::Kdump.crashkernel_list_ranges).to eq false
      end
    end

    context "when the param includes empty/nil entries" do
      let(:kernel_param) { [nil, ""] }

      it "reports presence of the param" do
        expect(Yast::Kdump.crashkernel_param).to eq true
      end

      it "schedules the writing on the param" do
        expect(Yast::Kdump.add_crashkernel_param).to eq true
      end

      it "does not find several ranges" do
        expect(Yast::Kdump.crashkernel_list_ranges).to eq false
      end

      it "empty value will be returned" do
        expect(Yast::Kdump.allocated_memory).to be_empty
      end
    end

    context "when the param is a number" do
      let(:kernel_param) { "32M" }

      it "reports presence of the param" do
        expect(Yast::Kdump.crashkernel_param).to eq true
      end

      it "schedules the writing on the param" do
        expect(Yast::Kdump.add_crashkernel_param).to eq true
      end

      it "does not find several ranges" do
        expect(Yast::Kdump.crashkernel_list_ranges).to eq false
      end

      it "correctly reads the size" do
        expect(Yast::Kdump.allocated_memory).to eq(low: "32")
      end
    end

    context "when the param is a range" do
      let(:kernel_param) { "64M-:32M" }

      it "reports presence of the param" do
        expect(Yast::Kdump.crashkernel_param).to eq true
      end

      it "schedules the writing on the param" do
        expect(Yast::Kdump.add_crashkernel_param).to eq true
      end

      it "does not find several ranges" do
        expect(Yast::Kdump.crashkernel_list_ranges).to eq false
      end

      it "correctly reads the size" do
        expect(Yast::Kdump.allocated_memory).to eq(low: "32")
      end
    end

    context "when the param includes several ranges" do
      let(:kernel_param) { "-200M:32M,200M-:64M" }

      it "reports presence of the param" do
        expect(Yast::Kdump.crashkernel_param).to eq true
      end

      it "schedules the writing on the param" do
        expect(Yast::Kdump.add_crashkernel_param).to eq true
      end

      it "finds several ranges" do
        expect(Yast::Kdump.crashkernel_list_ranges).to eq true
      end

      it "correctly reads the size of the first range" do
        expect(Yast::Kdump.allocated_memory).to eq(low: "32")
      end
    end

    context "when the param includes numbers with high and low" do
      let(:kernel_param) { ["64M,low", "128M,high"] }

      it "reports presence of the param" do
        expect(Yast::Kdump.crashkernel_param).to eq true
      end

      it "schedules the writing on the param" do
        expect(Yast::Kdump.add_crashkernel_param).to eq true
      end

      it "does not find several ranges" do
        expect(Yast::Kdump.crashkernel_list_ranges).to eq false
      end

      it "correctly reads both sizes" do
        expect(Yast::Kdump.allocated_memory).to eq(low: "64", high: "128")
      end
    end

    context "when the param is a number for high memory" do
      let(:kernel_param) { "128M,high" }

      it "reports presence of the param" do
        expect(Yast::Kdump.crashkernel_param).to eq true
      end

      it "schedules the writing on the param" do
        expect(Yast::Kdump.add_crashkernel_param).to eq true
      end

      it "does not find several ranges" do
        expect(Yast::Kdump.crashkernel_list_ranges).to eq false
      end

      it "correctly reads the size" do
        expect(Yast::Kdump.allocated_memory).to eq(high: "128")
      end
    end

    context "when the param uses ranges for both high and low" do
      let(:kernel_param) { ["-200M:32M,high", "64M-:16M"] }

      it "reports presence of the param" do
        expect(Yast::Kdump.crashkernel_param).to eq true
      end

      it "schedules the writing on the param" do
        expect(Yast::Kdump.add_crashkernel_param).to eq true
      end

      it "does not find several ranges" do
        expect(Yast::Kdump.crashkernel_list_ranges).to eq false
      end

      it "correctly reads the size" do
        expect(Yast::Kdump.allocated_memory).to eq(high: "32", low: "16")
      end
    end

    context "when the param uses complex ranges and types" do
      let(:kernel_param) { ["-200M:32M,200M-:64M,low", "1024-:128M,high"] }

      it "reports presence of the param" do
        expect(Yast::Kdump.crashkernel_param).to eq true
      end

      it "schedules the writing on the param" do
        expect(Yast::Kdump.add_crashkernel_param).to eq true
      end

      it "finds several ranges" do
        expect(Yast::Kdump.crashkernel_list_ranges).to eq true
      end

      it "correctly reads the size" do
        expect(Yast::Kdump.allocated_memory).to eq(high: "128", low: "32")
      end
    end

    context "when some type of memory (high, low) has several values" do
      let(:kernel_param) { ["64M", "128M,low"] }

      it "reports presence of the param" do
        expect(Yast::Kdump.crashkernel_param).to eq true
      end

      it "schedules the writing on the param" do
        expect(Yast::Kdump.add_crashkernel_param).to eq true
      end

      it "finds several ranges" do
        expect(Yast::Kdump.crashkernel_list_ranges).to eq true
      end

      it "correctly reads the first occurrence" do
        expect(Yast::Kdump.allocated_memory).to eq(low: "64")
      end
    end
  end

  describe ".WriteKdumpBootParameter" do
    before do
      Yast::Mode.SetMode(mode)
      # FIXME: current tests do not cover fadump (ppc64 specific)
      allow(Yast::Kdump.system).to receive(:supports_fadump?).and_return false
    end

    context "during autoinstallation" do
      let(:mode) { "autoinstallation" }

      before do
        Yast::Kdump.Import(profile)
      end

      context "if kdump is requested and a value for crashkernel is supplied" do
        let(:profile) { { "add_crash_kernel" => true, "crash_kernel" => "the_value" } }

        it "writes the crashkernel value to the bootloader and enables the service" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, "crashkernel" => ["the_value"])
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "if kdump is requested but no value for crashkernel is supplied" do
        let(:profile) { { "add_crash_kernel" => true } }

        it "writes an empty crashkernel in the bootloader and enables the service" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, "crashkernel" => [""])
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "if kdump is explicitly disabled" do
        let(:profile) { { "add_crash_kernel" => false, "crash_kernel" => "does_not_matter" } }

        it "disables the service not touching bootloader" do
          allow(Yast::Service).to receive(:active?).with("kdump").and_return false

          expect(Yast::Bootloader).to_not receive(:modify_kernel_params)
          expect(Yast::Bootloader).to_not receive(:Write)
          expect(Yast::Service).to receive(:Disable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "if kdump crashkernel contains an offset" do
        let(:profile) { { "add_crash_kernel" => true, "crash_kernel" => "72M@128" } }

        it "writes the crashkernel value without removing the offset" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, "crashkernel" => ["72M@128"])
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end
    end

    context "during autoupgrade" do
      let(:mode) { "autoupgrade" }

      before do
        Yast::Kdump.Import(profile)
      end

      context "if kdump is requested and a value for crashkernel is supplied" do
        let(:profile) { { "add_crash_kernel" => true, "crash_kernel" => "the_value" } }

        it "writes the crashkernel value to the bootloader and enables the service" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, "crashkernel" => ["the_value"])
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "if kdump is requested but no value for crashkernel is supplied" do
        let(:profile) { { "add_crash_kernel" => true } }

        it "writes an empty crashkernel in the bootloader and enables the service" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, "crashkernel" => [""])
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "if kdump is explicitly disabled" do
        let(:profile) { { "add_crash_kernel" => false, "crash_kernel" => "does_not_matter" } }

        it "disables the service not touching bootloader" do
          allow(Yast::Service).to receive(:Status).with("kdump").and_return(-1)

          expect(Yast::Bootloader).to_not receive(:modify_kernel_params)
          expect(Yast::Bootloader).to_not receive(:Write)
          expect(Yast::Service).to receive(:Disable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "if kdump crashkernel contains an offset" do
        let(:profile) { { "add_crash_kernel" => true, "crash_kernel" => "72M@128" } }

        it "writes the crashkernel value without removing the offset" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, "crashkernel" => ["72M@128"])
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end
    end

    context "in normal mode" do
      let(:mode) { "normal" }

      before do
        allow(Yast::Popup).to receive(:Message)
        allow(Yast::Bootloader).to receive(:kernel_param).and_return kernel_param
        Yast::Kdump.ReadKdumpKernelParam
      end

      context "crashkernel is already configured in the bootloader" do
        let(:kernel_param) { "64M" }

        it "updates crashkernel and enables service if crashkernel is changed" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, "crashkernel" => ["128M"])
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.allocated_memory = { low: "128" }
          Yast::Kdump.WriteKdumpBootParameter
        end

        it "enables the service but does not update crashkernel if it's not needed" do
          expect(Yast::Bootloader).to_not receive(:modify_kernel_params)
          expect(Yast::Bootloader).to_not receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.allocated_memory = { low: "64" }
          Yast::Kdump.WriteKdumpBootParameter
        end

        it "disables the service and removes crashkernel if kdump was disabled" do
          allow(Yast::Service).to receive(:active?).with("kdump").and_return false

          expect(Yast::Bootloader)
          .to receive(:modify_kernel_params)
          .with(:common, :xen_guest, :recovery, "crashkernel" => :missing)
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Disable).with("kdump")

          Yast::Kdump.add_crashkernel_param = false
          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "crashkernel is currently not configured in the bootloader" do
        let(:kernel_param) { :missing }

        it "writes chrashkernel and enables the service if kdump was enabled" do
          expect(Yast::Bootloader)
          .to receive(:modify_kernel_params)
          .with(:common, :xen_guest, :recovery, "crashkernel" => ["64M"])
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.allocated_memory = "64"
          Yast::Kdump.add_crashkernel_param = true
          Yast::Kdump.WriteKdumpBootParameter
        end

        it "disables the service not touching bootloader if kdump was not enabled" do
          allow(Yast::Service).to receive(:active?).with("kdump").and_return true

          expect(Yast::Bootloader).to_not receive(:modify_kernel_params)
          expect(Yast::Bootloader).to_not receive(:Write)
          expect(Yast::Service).to receive(:Disable).with("kdump")
          expect(Yast::Service).to receive(:Stop).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "not modifying the current bootloader value" do
        before do
          allow(Yast::Bootloader).to receive(:Write)
          allow(Yast::Service).to receive(:Enable).with("kdump")
        end

        context "if the value includes an offset" do
          let(:kernel_param) { "64M@512" }

          it "removes the range" do
            expect(Yast::Bootloader)
              .to receive(:modify_kernel_params)
              .with(:common, :xen_guest, :recovery, {"crashkernel" => ["64M"]})
            Yast::Kdump.WriteKdumpBootParameter
          end
        end

        context "if the value includes several ranges and an offset" do
          let(:kernel_param) { "-512M:64M,512M-:128M@1024" }

          it "does not try to write a new value" do
            expect(Yast::Bootloader).to_not receive(:modify_kernel_params)
            Yast::Kdump.WriteKdumpBootParameter
          end
        end
      end
    end

    context "during update" do
      let(:mode) { "update" }

      before do
        allow(Yast::Popup).to receive(:Message)
        allow(Yast::Bootloader).to receive(:kernel_param).and_return kernel_param
        allow(Yast::Bootloader).to receive(:Write)
        allow(Yast::Service).to receive(:Enable).with("kdump")

        Yast::Kdump.ReadKdumpKernelParam
      end

      context "if the crashkernel value includes an offset" do
        let(:kernel_param) { "64M@512" }

        it "removes the offset" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, {"crashkernel" => ["64M"]})
          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "if the value includes several ranges and an offset" do
        let(:kernel_param) { "-512M:64M,512M-:128M@1024" }

        it "removes the offset" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, {"crashkernel" => ["-512M:64M,512M-:128M"]})
          Yast::Kdump.WriteKdumpBootParameter
        end
      end
    end
  end

  describe ".Update" do
    before do
      Yast::Mode.SetMode(mode)
    end

    context "in update mode" do
      let(:mode) { "update" }

      it "reads kernel param, update kdump boot parameter and returns true" do
        expect(Yast::Kdump).to receive(:ReadKdumpKernelParam)
        expect(Yast::Kdump).to receive(:WriteKdumpBootParameter)
        expect(Yast::Kdump.Update).to eq(true)
      end
    end

    context "in update mode" do
      let(:mode) { "autoupgrade" }

      it "does not reads kernel param but update kdump boot parameter and returns true" do
        expect(Yast::Kdump).to_not receive(:ReadKdumpKernelParam)
        expect(Yast::Kdump).to receive(:WriteKdumpBootParameter)
        expect(Yast::Kdump.Update).to eq(true)
      end
    end
  end

  describe ".allocated_memory=" do
    subject(:memory) { Yast::Kdump.allocated_memory }

    it "assigns the argument to :low if it's a string" do
      Yast::Kdump.allocated_memory = "32"
      expect(memory).to eq(low: "32")
    end

    it "empties the value if the argument is the empty string" do
      Yast::Kdump.allocated_memory = ""
      expect(memory).to eq({})
    end

    it "assigns the argument if it's a hash" do
      Yast::Kdump.allocated_memory = { high: "64", low: "32" }
      expect(memory).to eq(high: "64", low: "32")
    end
  end

  describe ".AutoYaST" do
    before do
      Yast::Mode.SetMode(mode)
    end

    context "during profile import" do
      let(:mode) { "autoinstallation" }
      let(:profile) { {"add_crash_kernel"=>true,
                        "crash_kernel"=>"256M",
                        "general"=>{"KDUMP_SAVEDIR"=>"file:///var/dummy"}
                      }
                    }
      # bnc#995750
      it "imported values will not be overwritten by the proposal" do
        Yast::Kdump.Import(profile)
        Yast::Kdump.Propose
        ret = Yast::Kdump.Export
        expect(ret["add_crash_kernel"]).to eq(profile["add_crash_kernel"])
        expect(ret["crash_kernel"]).to eq(profile["crash_kernel"])
        expect(ret["general"]["KDUMP_SAVEDIR"]).to eq(profile["general"]["KDUMP_SAVEDIR"])
      end
    end
  end

end
