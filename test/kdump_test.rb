#!/usr/bin/env rspec

require_relative "./test_helper"

Yast.import "Kdump"
Yast.import "Mode"
Yast.import "Bootloader"
Yast.import "Service"
Yast.import "Popup"
Yast.import "SpaceCalculation"

describe Yast::Kdump do
  before do
    Yast::Kdump.reset
  end

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
        expect(Yast::Kdump.allocated_memory).to eq "32"
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
        expect(Yast::Kdump.allocated_memory).to eq "32"
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
        expect(Yast::Kdump.allocated_memory).to eq "32"
      end
    end
  end

  describe ".WriteKdumpBootParameter" do
    context "during autoinstallation" do
      before do
        Yast::Mode.SetMode("autoinstallation")
        Yast::Kdump.Import(profile)
      end

      context "if kdump is requested and a value for crashkernel is supplied" do
        let(:profile) { {"add_crash_kernel" => true, "crash_kernel" => "the_value"} }

        it "writes the crashkernel value to the bootloader and enables the service" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, {"crashkernel" => "the_value"})
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "if kdump is requested but no value for crashkernel is supplied" do
        let(:profile) { {"add_crash_kernel" => true} }

        it "writes an empty crashkernel in the bootloader and enables the service" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, {"crashkernel" => ""})
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "if kdump is explicitly disabled" do
        let(:profile) { {"add_crash_kernel" => false, "crash_kernel" => "does_not_matter"} }

        it "disables the service not touching bootloader" do
          allow(Yast::Service).to receive(:Status).with("kdump").and_return -1

          expect(Yast::Bootloader).to_not receive(:modify_kernel_params)
          expect(Yast::Bootloader).to_not receive(:Write)
          expect(Yast::Service).to receive(:Disable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "if kdump crashkernel contains an offset" do
        let(:profile) { {"add_crash_kernel" => true, "crash_kernel" => "72M@128"} }

        it "writes the crashkernel value without removing the offset" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, {"crashkernel" => "72M@128"})
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end
    end

    context "during autoupgrade" do
      before do
        Yast::Mode.SetMode("autoupgrade")
        Yast::Kdump.Import(profile)
      end

      context "if kdump is requested and a value for crashkernel is supplied" do
        let(:profile) { {"add_crash_kernel" => true, "crash_kernel" => "the_value"} }

        it "writes the crashkernel value to the bootloader and enables the service" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, {"crashkernel" => "the_value"})
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "if kdump is requested but no value for crashkernel is supplied" do
        let(:profile) { {"add_crash_kernel" => true} }

        it "writes an empty crashkernel in the bootloader and enables the service" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, {"crashkernel" => ""})
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "if kdump is explicitly disabled" do
        let(:profile) { {"add_crash_kernel" => false, "crash_kernel" => "does_not_matter"} }

        it "disables the service not touching bootloader" do
          allow(Yast::Service).to receive(:Status).with("kdump").and_return -1

          expect(Yast::Bootloader).to_not receive(:modify_kernel_params)
          expect(Yast::Bootloader).to_not receive(:Write)
          expect(Yast::Service).to receive(:Disable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "if kdump crashkernel contains an offset" do
        let(:profile) { {"add_crash_kernel" => true, "crash_kernel" => "72M@128"} }

        it "writes the crashkernel value without removing the offset" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, {"crashkernel" => "72M@128"})
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.WriteKdumpBootParameter
        end
      end
    end

    context "in normal mode" do
      before do
        Yast::Mode.SetMode("normal")
        allow(Yast::Popup).to receive(:Message)

        allow(Yast::Bootloader).to receive(:kernel_param).and_return kernel_param
        Yast::Kdump.ReadKdumpKernelParam
      end

      context "crashkernel is already configured in the bootloader" do
        let(:kernel_param) { "128M-:64M" }

        it "updates crashkernel and enables service if crashkernel is changed" do
          size = 128

          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, {"crashkernel" => "#{size*2}M-:#{size}M"})
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.allocated_memory = size.to_s
          Yast::Kdump.WriteKdumpBootParameter
        end

        it "enables the service but does not update crashkernel if it's not needed" do
          expect(Yast::Bootloader).to_not receive(:modify_kernel_params)
          expect(Yast::Bootloader).to_not receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.allocated_memory = "64"
          Yast::Kdump.WriteKdumpBootParameter
        end

        it "disables the service and removes crashkernel if kdump was disabled" do
          allow(Yast::Service).to receive(:Status).and_return -1

          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, {"crashkernel" => :missing})
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Disable).with("kdump")

          Yast::Kdump.add_crashkernel_param = false
          Yast::Kdump.WriteKdumpBootParameter
        end
      end

      context "crashkernel is currently not configured in the bootloader" do
        let (:kernel_param) { :missing }

        it "writes chrashkernel and enables the service if kdump was enabled" do
          expect(Yast::Bootloader)
            .to receive(:modify_kernel_params)
            .with(:common, :xen_guest, :recovery, {"crashkernel" => "128M-:64M"})
          expect(Yast::Bootloader).to receive(:Write)
          expect(Yast::Service).to receive(:Enable).with("kdump")

          Yast::Kdump.allocated_memory = "64"
          Yast::Kdump.add_crashkernel_param = true
          Yast::Kdump.WriteKdumpBootParameter
        end

        it "disables the service not touching bootloader if kdump was not enabled" do
          allow(Yast::Service).to receive(:Status).and_return 0

          expect(Yast::Bootloader).to_not receive(:modify_kernel_params)
          expect(Yast::Bootloader).to_not receive(:Write)
          expect(Yast::Service).to receive(:Disable).with("kdump")
          expect(Yast::Service).to receive(:Stop).with("kdump")

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
end
