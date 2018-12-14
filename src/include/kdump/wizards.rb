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

# File:	include/kdump/wizards.ycp
# Package:	Configuration of kdump
# Summary:	Wizards definitions
# Authors:	Jozef Uhliarik <juhliarik@suse.com>
#
# $Id: wizards.ycp 27914 2006-02-13 14:32:08Z locilka $
module Yast
  module KdumpWizardsInclude
    def initialize_kdump_wizards(include_target)
      Yast.import "UI"

      textdomain "kdump"

      Yast.import "Sequencer"
      Yast.import "Wizard"
      Yast.import "Stage"

      Yast.include include_target, "kdump/complex.rb"
      Yast.include include_target, "kdump/dialogs.rb"
    end

    # Main workflow of the kdump configuration
    # @return sequence result
    def MainSequence
      aliases = { "conf" => lambda { RunKdumpDialogs() } }

      sequence = {
        "ws_start" => "conf",
        "conf"     => { :abort => :abort, :next => :next }
      }

      ret = Sequencer.Run(aliases, sequence)
      deep_copy(ret)
    end

    # Whole configuration of kdump
    # @return sequence result
    def KdumpSequence
      aliases = {
        "read"  => [lambda { ReadDialog() }, true],
        "main"  => lambda { MainSequence() },
        "write" => [lambda { WriteDialog() }, true]
      }

      sequence = {
        "ws_start" => "read",
        "read"     => { :abort => :abort, :next => "main" },
        "main"     => { :abort => :abort, :next => "write" },
        "write"    => { :abort => :abort, :next => :next }
      }

      Wizard.CreateDialog
      if Mode.normal
        Wizard.SetDesktopTitleAndIcon("kdump")
      else
        Wizard.SetTitleIcon("yast-kdump")
      end

      ret = Sequencer.Run(aliases, sequence)
      UI.CloseDialog
      deep_copy(ret)
    end

    # Whole configuration of kdump but without reading and writing.
    # For use with autoinstallation.
    # @return sequence result
    def KdumpAutoSequence
      Wizard.CreateDialog
      Wizard.SetContentsButtons(
        "",
        VBox(),
        "",
        Label.BackButton,
        Label.NextButton
      )
      if Stage.initial
        Wizard.SetTitleIcon("kdump") # no .desktop file in inst-sys
      else
        Wizard.SetDesktopIcon("kdump")
      end
      ret = MainSequence()
      UI.CloseDialog
      deep_copy(ret)
    end
  end
end
