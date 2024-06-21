# ------------------------------------------------------------------------------
# Copyright (c) 2008 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:	kdump_proposal.ycp
# Package:	Configuration of kdump
# Summary:	Proposal handlingss
# Authors:	Jozef Uhliarik <juhliarik@suse.com>
#
module Yast
  class KdumpProposalClient < Client
    def main
      Yast.import "UI"
      textdomain "kdump"

      Yast.import "Kdump"
      Yast.import "Mode"

      Yast.include self, "kdump/wizards.rb"

      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}

      case @func
      when "MakeProposal"
        Kdump.Propose

        @ret = {
          "raw_proposal"   => Kdump.Summary,
          "label_proposal" => Kdump.Summary[0..0],
          # FATE#317488 When expectation at the end of proposal does not match
          # the value, this proposal will be called again
          "trigger"        => {
            "expect" => {
              "class"  => "Yast::Kdump",
              "method" => "free_space_for_dump_b"
            },
            "value"  => Yast::Kdump.free_space_for_dump_b
          }
        }

        @ret.merge!(Kdump.proposal_warning)
      when "AskUser"
        @has_next = Ops.get_boolean(@param, "has_next", false)
        @settings = Kdump.Export
        Kdump.modified = false
        @result = KdumpAutoSequence()
        Kdump.SetModified
        if @result != :next
          Kdump.Import(
            Convert.convert(
              @settings,
              :from => "map",
              :to   => "map <string, any>"
            )
          )
        end

        # if disable kdump deselect packages for installation
        # Kdump::CheckPackages();
        # Fill return map
        @ret = { "workflow_sequence" => @result }
      when "Description"
        @ret = {
          # proposal part - kdump label
          "rich_text_title" => _("Kdump"),
          # menubutton entry
          "menu_title"      => _("&Kdump"),
          "id"              => "kdump_stuff"
        }
      when "Write"
        # Write is called in finish script (kdump_finish.ycp)
        # it is necessary do it after bootloader write his settings
        # boolean succ = Kdump::Write ();
        @ret = { "success" => true }
      end

      deep_copy(@ret)
    end
  end
end

Yast::KdumpProposalClient.new.main
