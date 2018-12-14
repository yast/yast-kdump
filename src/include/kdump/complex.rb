# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006 Novell, Inc. All Rights Reserved.
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

# File:	include/kdump/complex.ycp
# Package:	Configuration of kdump
# Summary:	Dialogs definitions
# Authors:	Jozef Uhliarik <juhliarik@suse.com>
#
# $Id: complex.ycp 29363 2006-03-24 08:20:43Z mzugec $
module Yast
  module KdumpComplexInclude
    def initialize_kdump_complex(include_target)
      Yast.import "UI"

      textdomain "kdump"

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Confirm"
      Yast.import "Kdump"
      Yast.import "Package"
      Yast.import "Arch"
      Yast.import "Report"
      Yast.import "Mode"
      Yast.import "Message"
      Yast.import "PackageSystem"

      Yast.include include_target, "kdump/helps.rb"
    end

    # Return a modification status
    # @return true if data was modified
    def Modified
      Kdump.GetModified
    end

    def ReallyAbort
      !Kdump.GetModified || Popup.ReallyAbort(true)
    end

    def PollAbort
      UI.PollInput == :abort
    end

    # @return true if necessary packages are installed
    def InstallPackages
      # install packages
      package_list = KdumpClass::KDUMP_PACKAGES
      if !PackageSystem.CheckAndInstallPackages(package_list)
        Report.Error(Message.CannotContinueWithoutPackagesInstalled)
        Builtins.y2error(
          "[kdump] Installation of package list %1 failed or aborted",
          package_list
        )
        return false
      end

      true
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "read", ""))
      # Kdump::AbortFunction = PollAbort;
      return :abort if !Confirm.MustBeRoot
      if !Kdump.system.supports_kdump? && !unsupported_kdump_confirmation
        return :abort
      end
      InstallPackages() or return :abort

      ret = Kdump.Read
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "write", ""))
      # Kdump::AbortFunction = PollAbort;
      ret = Kdump.Write
      ret ? :next : :abort
    end
  end
end
