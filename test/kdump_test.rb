#!/usr/bin/env rspec
ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
include Yast
Yast.import "Kdump"

describe Kdump do
  # NOTE Kdump misspells "allocate" as "alocate"
  # alocated_memory is a string   in megabytes
  # total_memory    is an integer in megabytes
  describe "#ProposeAlocatedMemory" do
    context "when already proposed" do
      before(:each) do
        Kdump.alocated_memory = "42"
      end
      it "returns the current value" do
        Kdump.ProposeAlocatedMemory
        expect(Kdump.alocated_memory).to eq "42"
      end
    end

    context "when not yet proposed" do
      before(:each) do
        Kdump.alocated_memory = "0"
      end

      PHYSICAL_TO_PROPOSED_MB = {
          "x86_64" => [
            [       256,    0],
            [       512,   64],
            [  1 * 1024,   64],
            [  2 * 1024,  128],
            [ 20 * 1024,  128]
          ],
          "ppc64" => [
            [       256,    0],
            [       512,  128],
            [  1 * 1024,  128],
            [  2 * 1024,  256],
            [ 20 * 1024,  256]
          ],
          "ia64" => [
            [       256,    0],
            [       512,   64],
            [  1 * 1024,  256],
            [  2 * 1024,  256],
            [  8 * 1024,  512],
            [128 * 1024,  768],
            [256 * 1024, 1024],
            [378 * 1024, 1536],
            [512 * 1024, 2048],
            [768 * 1024, 3072]
          ],
      }

      PHYSICAL_TO_PROPOSED_MB.each do |arch, pair|
        context "on #{arch}" do
          before(:each) do
            Arch.stub(:architecture) { arch }
          end

          pair.each do |physical_mb, proposed_mb|
            it "proposes #{proposed_mb}MB for #{physical_mb}MB physical memory" do
              Kdump.total_memory = physical_mb
              Kdump.ProposeAlocatedMemory
              expect(Kdump.alocated_memory).to eq proposed_mb.to_s
            end
          end
        end
      end
    end
  end
end
