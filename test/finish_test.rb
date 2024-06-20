#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "./test_helper"

require "kdump/clients/finish"

describe Y2Kdump::Clients::Finish do
  describe "#steps" do
    it "returns an integer" do
      expect(subject.steps).to be_an Integer
    end
  end

  describe "#title" do
    it "returns a string" do
      expect(subject.title).to be_a String
    end
  end

  describe "#modes" do
    it "returns a list" do
      modes = subject.modes
      # If we want to make this a generic FinishClient test,
      # remember the API allows a nil
      expect(modes).to be_an Array
      modes.each do |m|
        # elements are fixed symbol values
        expect(m).to be_a Symbol
      end
    end
  end

  describe "#write" do
    before do
      allow(Yast::Kdump).to receive(:Propose)
      Yast::Kdump.import_called = false
    end

    it "calls Kdump.Write for installing" do
      expect(Yast::Mode).to receive(:update).and_return(false)
      expect(Yast::Kdump).to receive(:Write)
      subject.write
    end

    it "calls Kdump.Update for updating" do
      expect(Yast::Mode).to receive(:update).and_return(true)
      expect(Yast::Kdump).to receive(:Update)
      subject.write
    end
  end
end
