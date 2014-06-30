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
      Yast.import "CommandLine"
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

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      kexec_installed = false
      kdump_installed = false
      kexec_available = false
      kdump_available = false
      package_list = []

      Wizard.RestoreHelp(Ops.get_string(@HELPS, "read", ""))
      # Kdump::AbortFunction = PollAbort;
      return :abort if !Confirm.MustBeRoot

      # checking of installation packages
      kexec_installed = true if Package.Installed("kexec-tools")

      # kexec-tools depends on it.
      kdump = "kdump"
      kdump_installed = true if Package.Installed(kdump)

      #checking if packages are available
      if !kexec_installed || !kdump_installed
        kexec_available = Package.Available("kexec-tools") if !kexec_installed

        kdump_available = Package.Available(kdump) if !kdump_installed

        if !kexec_installed && !kexec_available
          if !Mode.commandline
            Popup.Error(_("Package for kexec-tools is not available."))
          else
            CommandLine.Error(_("Package for kexec-tools is not available."))
          end
          Builtins.y2error(
            "[kdump] (ReadDialog ()) Packages for kexec-tools is not available."
          )
          return :abort
        end

        if !kdump_installed && !kdump_available
          if !Mode.commandline
            Popup.Error(_("Package for kdump is not available."))
          else
            CommandLine.Error(_("Package for kdump is not available."))
          end
          Builtins.y2error(
            "[kdump] (ReadDialog ()) Packages for %1 is not available.",
            kdump
          )
          return :abort
        end

        #add packages for installation
        if !kexec_installed
          package_list = Builtins.add(package_list, "kexec-tools")
        end

        package_list = Builtins.add(package_list, kdump) if !kdump_installed

        #install packages
        if !PackageSystem.CheckAndInstallPackages(package_list)
          if !Mode.commandline
            Popup.Error(Message.CannotContinueWithoutPackagesInstalled)
          else
            CommandLine.Error(Message.CannotContinueWithoutPackagesInstalled)
          end
          Builtins.y2error(
            "[kdump] Installation of package list %1 failed or aborted",
            package_list
          )
          return :abort
        end
      end

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
