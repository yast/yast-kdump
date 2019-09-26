# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "installation/auto_client"

Yast.import "Kdump"
Yast.import "Mode"
Yast.import "Progress"
Yast.import "PackagesProposal"

module Y2Kdump
  module Clients
    # Client to communicate with autoyast
    class Auto < ::Installation::AutoClient
      def initialize
        textdomain "kdump"

        Yast.include self, "kdump/wizards.rb" # needed for auto sequence
      end

      def import(profile)
        Yast::Kdump.Import(profile)
        # add packages needed to proposal, as it is needed already in first stage (bsc#1149208)
        Yast::PackagesProposal.AddResolvables("yast2-kdump", :package, packages["install"])
      end

      def export
        Yast::Kdump.Export
      end

      def summary
        items = Yast::Kdump.Summary.map { |s| "<li>#{s}</li>" }
        "<ul>#{items.join("\n")}</ul>"
      end

      def modified?
        Yast::Kdump.GetModified
      end

      def modified
        Yast::Kdump.SetModified
      end

      def reset
        Yast::Kdump.Import({})
      end

      def change
        KdumpAutoSequence()
      end

      def write
        progress_orig = Yast::Progress.set(false)
        Yast::Kdump.Write
        Yast::Progress.set(progress_orig)
      end

      def read
        progress_orig = Yast::Progress.set(false)
        Yast::Kdump.Read
        Yast::Progress.set(progress_orig)
      end

      def packages
        if Yast::Kdump.add_crashkernel_param
          {
            "install" => Yast::KdumpClass::KDUMP_PACKAGES,
            "remove"  => []
          }
        else
          {}
        end
      end
    end
  end
end
