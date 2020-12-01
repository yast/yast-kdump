require_relative "./test_helper"
require_relative "../src/clients/kdump"
Yast.import "CommandLine"

describe Yast::KdumpClient do

  describe ".cmdKdumpStartup" do
    let(:alloc_mem_high) { "100" }
    let(:alloc_mem_low) { "50" }

    before do
      allow(Yast::Arch).to receive(:paravirtualized_xen_guest?).and_return(false)
    end

    context "When using wrong inputs in alloc memory" do
      let(:options) { { "enable" => "", "alloc_mem" => "#{alloc_mem_low}:#{alloc_mem_high}" } }

      it "does not enable kdump and returns false" do
        expect(subject.cmdKdumpStartup(options)).to be false
      end
    end

    context "When using alloc memory high and low" do
      let(:options) { { "enable" => "", "alloc_mem" => "#{alloc_mem_low},#{alloc_mem_high}" } }

      it "sets the low and high values of  Kdump allocated_memory " do
        subject.cmdKdumpStartup(options)
        expect(Yast::Kdump.allocated_memory).to eq(low:  alloc_mem_low, high: alloc_mem_high)
        expect(Yast::Kdump.add_crashkernel_param).to be true
      end
    end

    context "when using only alloc memory low" do
      let(:options) { { "enable" => "", "alloc_mem" => alloc_mem_low.to_s } }

      it "enables only the low value of Kdump allocated_memory " do
        subject.cmdKdumpStartup(options)
        expect(Yast::Kdump.allocated_memory).to eq(low:  alloc_mem_low, high: nil)
        expect(Yast::Kdump.add_crashkernel_param).to be true
      end
    end

    context "When receives the 'disable' option" do
      let(:options) { { "disable"=>"" } }

      it "sets kdump to be disabled" do
        subject.cmdKdumpStartup(options)
        expect(Yast::Kdump.add_crashkernel_param).to be false
      end
    end
  end
end
