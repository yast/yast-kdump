# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
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

require "installation/finish_client"

module Y2Kdump
  module Clients
    # Client to write kdump at the end of installation
    class Finish < ::Installation::FinishClient
      def initialize
        textdomain "kdump"

        Yast.import "Kdump"
        Yast.import "Mode"
        Yast.import "Progress"
        super
      end

      def title
        # progress step title
        _("Saving kdump configuration...")
      end

      def modes
        [:installation, :update, :autoinst]
      end

      def steps
        3
      end

      def write
        progress_orig = Progress.set(false)
        # propose settings for kdump
        # if autoyast doesn't include settings for yast2-kdump
        Kdump.Propose if !Kdump.import_called && Mode.auto
        if Mode.update
          Kdump.Update
        else
          Kdump.Write
        end
        Progress.set(progress_orig)
      end
    end
  end
end
