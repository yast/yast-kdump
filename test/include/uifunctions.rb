#!/usr/bin/env rspec

require_relative "../test_helper"

describe "Yast::KdumpUifunctionsInclude" do

  # Dummy client to test KdumpUifunctionsInclude
  module DummyYast
    class KdumpClient < Yast::Client
      def main
        Yast.include self, "kdump/uifunctions.rb"
      end

      def initialize
        main
      end

      # Convenience method to expose @KDUMP_SAVE_TARGET
      def target
        @KDUMP_SAVE_TARGET
      end
    end
  end

  DEFAULT_KDUMP_SAVE_TARGET = {
    "target"    => "file",
    "server"    => "",
    "dir"       => "",
    "user_name" => "",
    "port"      => "",
    "share"     => "",
    "password"  => ""
  }

  # Builds a target specification merging default values with new ones
  #
  # This is just a helper method for convenience.
  #
  # @param [Hash] attrs Attributes to override.
  # @return [Hash]      Target specification with overriden attributes.
  def build_target(attrs = {})
    DEFAULT_KDUMP_SAVE_TARGET.merge(attrs)
  end

  subject(:client) { DummyYast::KdumpClient.new }

  describe "#SetUpKDUMP_SAVE_TARGET" do
    context "when target has no type" do
      let(:target) { "/var/crash" }

      it "sets KDUMP_SAVE_TARGET as 'file' with path '/var/crash'" do
        expect(client.SetUpKDUMP_SAVE_TARGET(target)).to eq(true)
        expect(client.target).to eq(build_target("dir" => "/var/crash", "target" => "file"))
      end
    end

    context "when target is like 'file:///var/crash'" do
      let(:target) { "file:///var/crash" }

      it "sets KDUMP_SAVE_TARGET as 'file' with path '/var/crash'" do
        expect(client.SetUpKDUMP_SAVE_TARGET(target)).to eq(true)
        expect(client.target).to eq(build_target("dir" => "/var/crash", "target" => "file"))
      end
    end

    context "when target is like 'ftp://user:pass@ftp.suse.com/pub'" do
      let(:target) { "ftp://user:pass@ftp.suse.com/pub" }

      it "sets KDUMP_SAVE_TARGET as 'ftp' with server, user_name, password and dir" do
        expect(client.SetUpKDUMP_SAVE_TARGET(target)).to eq(true)
        expect(client.target).to eq(build_target(
          "target" => "ftp", "user_name" => "user", "password" => "pass",
          "server" => "ftp.suse.com", "dir" => "/pub"))
      end
    end

    context "when target is like 'nfs://ftp.suse.cz/exports'" do
      let(:target) { "nfs://nfs.suse.cz/exports" }

      it "sets KDUMP_SAVE_TARGET as 'nfs' with server and dir" do
        expect(client.SetUpKDUMP_SAVE_TARGET(target)).to eq(true)
        expect(client.target).to eq(build_target(
          "target" => "nfs", "server" => "nfs.suse.cz", "dir" => "/exports"))
      end
    end

    context "when target is like 'ssh://user:pass@people.suse.cz:9000/home/user/kdump'" do
      let(:target) { "ssh://user:pass@people.suse.cz:9000/home/user/kdump" }

      it "sets KDUMP_SAVE_TARGET as 'ssh' with server, port, user_name, password and dir" do
        expect(client.SetUpKDUMP_SAVE_TARGET(target)).to eq(true)
        expect(client.target).to eq(build_target(
          "target" => "ssh", "user_name" => "user", "password" => "pass",
          "server" => "people.suse.cz", "dir" => "/home/user/kdump", "port" => "9000"))
      end
    end

    context "when target is like 'sftp://user:pass@people.suse.cz:9000/home/user/kdump'" do
      let(:target) { "sftp://user:pass@people.suse.cz:9000/home/user/kdump" }

      it "sets KDUMP_SAVE_TARGET 'sftp' with server, port, user_name, password and dir" do
        expect(client.SetUpKDUMP_SAVE_TARGET(target)).to eq(true)
        expect(client.target).to eq(build_target(
          "target" => "sftp", "user_name" => "user", "password" => "pass",
          "server" => "people.suse.cz", "dir" => "/home/user/kdump", "port" => "9000"))
      end
    end

    context "when target is like 'cifs://user:pass@people.suse.cz/homes/user/kdump'" do
      let(:target) { "cifs://user:pass@people.suse.cz/homes/user/kdump" }

      it "sets KDUMP_SAVE_TARGET 'cifs' with server, user_name, password, share and dir" do
        expect(client.SetUpKDUMP_SAVE_TARGET(target)).to eq(true)
        expect(client.target).to eq(build_target(
          "target" => "cifs", "user_name" => "user", "password" => "pass",
          "server" => "people.suse.cz", "dir" => "/user/kdump", "share" => "homes"
        ))
      end
    end

    context "when target is empty" do
      let(:target) { "" }

      it "returns false" do
       expect(client.SetUpKDUMP_SAVE_TARGET(target)).to eq(false)
      end
    end

  end
end
