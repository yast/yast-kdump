#!/usr/bin/env rspec

require_relative "./test_helper"

Yast.import "Kdump"

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
end
