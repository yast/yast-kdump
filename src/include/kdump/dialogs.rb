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
  module KdumpDialogsInclude
    def initialize_kdump_dialogs(include_target)
      textdomain "kdump"

      Yast.import "CWM"
      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "Kdump"
      Yast.import "DialogTree"
      Yast.import "CWMTab"

      Yast.include include_target, "kdump/helps.rb"
      Yast.include include_target, "kdump/uifunctions.rb"

      @wid_handling = {
        "DisBackButton"          => {
          "widget"        => :custom,
          "custom_widget" => Empty(),
          "init"          => fun_ref(method(:DisBackButton), "void (string)"),
          "help"          => " "
        },
        #---------============ Start-up screen=============------------
        "EnableDisalbeKdump"     => {
          #TRANSLATORS: RadioButtonGroup Label
          "label"       => _(
            "Enable/Disable Kdump"
          ),
          "widget"      => :radio_buttons,
          "items"       => [
            ["enable_kdump", _("Enable Kd&ump")],
            ["disable_kdump", _("&Disable Kdump")]
          ],
          "orientation" => :horizontal,
          "init"        => fun_ref(
            method(:InitEnableDisalbeKdump),
            "void (string)"
          ),
          #"handle"		: HandleEnableDisalbeKdump,
          "store"       => fun_ref(
            method(:StoreEnableDisalbeKdump),
            "void (string, map)"
          ),
          "help"        => HelpKdump("StartRadioBut")
        },
        "KdumpMemory"            => {
          "widget"            => :custom,
          "custom_widget"     => HSquash(
            VBox(
              Left(
                HBox(
                  Left(Label(_("Total System Memory [MB]:"))),
                  Left(Label(Id("total_memory"), "0123456789")),
                  HStretch()
                )
              ),
              Left(
                HBox(
                  Left(Label(_("Usable Memory [MB]:"))),
                  Left(Label(Id("usable_memory"), "0123456789")),
                  HStretch()
                )
              ),
              Left(
                IntField(
                  Id("allocated_memory"),
                  Opt(:notify),
                  _("Kdump Memor&y [MB]"),
                  32,
                  1048576,
                  128
                )
              )
            )
          ),
          "init"              => fun_ref(
            method(:InitKdumpMemory),
            "void (string)"
          ),
          "handle"            => fun_ref(
            method(:HandleKdumpMemory),
            "symbol (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidKdumpMemory),
            "boolean (string, map)"
          ),
          "store"             => fun_ref(
            method(:StoreKdumpMemory),
            "void (string, map)"
          ),
          "help"              => HelpKdump("KdumpMemory")
        },
        "FADump"   => {
          "widget" => :custom,
          "custom_widget" => Empty(),
          "init"   => fun_ref(method(:InitFADump), "void (string)"),
          "handle" => fun_ref(method(:HandleFADump), "void (string, map)"),
          "help"   => HelpKdump("FADump"),
        },
        #---------============ Dump Filtering screen=============------------
        "DumpLevel"              => {
          "widget"            => :custom,
          "custom_widget"     => VBox(
            Frame(
              _("Include in Dumping"),
              VBox(
                Left(
                  HBox(
                    HSpacing(1),
                    VBox(
                      Left(
                        CheckBox(Id("zero_page"), _("&Pages Filled with Zero"))
                      ), #`VStretch ()
                      Left(
                        CheckBox(
                          Id("cache_page"),
                          Opt(:notify),
                          _("Cach&e Pages")
                        )
                      ),
                      HBox(
                        HSpacing(2),
                        VBox(
                          Left(
                            CheckBox(
                              Id("cache_private"),
                              Opt(:notify),
                              _("Cache Priva&te Pages")
                            )
                          )
                        )
                      ),
                      Left(CheckBox(Id("user_data"), _("&User Data Pages"))),
                      Left(CheckBox(Id("free_page"), _("&Free Pages")))
                    )
                  )
                )
              )
            )
          ),
          "init"              => fun_ref(
            method(:InitDumpLevel),
            "void (string)"
          ),
          "handle"            => fun_ref(
            method(:HandleDumpLevel),
            "symbol (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidDumpLevel),
            "boolean (string, map)"
          ),
          "store"             => fun_ref(
            method(:StoreDumpLevel),
            "void (string, map)"
          ),
          "help"              => HelpKdump("DumpLevel")
        },
        "DumpFormat"             => {
          #TRANSLATORS: TextEntry Label
          "label"             => _("&Dump Format"),
          "widget"            => :radio_buttons,
          "items"             => [
            ["none_format", _("&No Dump")],
            ["elf_format", _("&ELF Format")],
            ["compressed_format", _("C&ompressed Format")],
            ["lzo_format", _("&LZO Compressed Format")]
          ],
          "orientation"       => :horizontal,
          "init"              => fun_ref(
            method(:InitDumpFormat),
            "void (string)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidDumpFormat),
            "boolean (string, map)"
          ),
          "store"             => fun_ref(
            method(:StoreDumpFormat),
            "void (string, map)"
          ),
          "help"              => HelpKdump("DumpFormat")
        },
        #---------============ Dump Target screen=============------------
        "TargetKdump"            => {
          "label"             => _("&Select Target"),
          "widget"            => :combobox,
          "opt"               => [:notify],
          "items"             => [
            ["local_filesystem", _("Local Directory")],
            ["ftp", _("FTP")],
            ["ssh", _("SSH (scp)")],
            ["nfs", _("NFS")],
            ["cifs", _("CIFS (SMB)")]
          ],
          "init"              => fun_ref(
            method(:InitTargetKdump),
            "void (string)"
          ),
          #"handle_events" 	: ["TargetKdump2"],
          "handle"            => fun_ref(
            method(:HandleTargetKdump),
            "symbol (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidTargetKdump),
            "boolean (string, map)"
          ),
          "store"             => fun_ref(
            method(:StoreTargetKdump),
            "void (string, map)"
          ),
          "help"              => HelpKdump("TargetKdump")
        },
        #---------============ Email Notification screen=============------------
        "SMTPServer"             => {
          #TRANSLATORS: TextEntry Label
          "label"  => _("&SMTP Server"),
          "widget" => :textentry,
          "init"   => fun_ref(method(:InitSMTPServer), "void (string)"),
          #"handle"		:
          "store"  => fun_ref(
            method(:StoreSMTPServer),
            "void (string, map)"
          ),
          "help"   => HelpKdump("SMTPServer")
        },
        "SMTPUser"               => {
          #TRANSLATORS: TextEntry Label
          "label"  => _("&User Name"),
          "widget" => :textentry,
          "init"   => fun_ref(method(:InitSMTPUser), "void (string)"),
          #"handle"		:
          "store"  => fun_ref(
            method(:StoreSMTPUser),
            "void (string, map)"
          ),
          "help"   => HelpKdump("SMTPUser")
        },
        "SMTPPassword"           => {
          #TRANSLATORS: TextEntry Label
          "label"  => _("&Password"),
          "widget" => :password,
          "init"   => fun_ref(method(:InitSMTPPassword), "void (string)"),
          #"handle"		:
          "store"  => fun_ref(
            method(:StoreSMTPPassword),
            "void (string, map)"
          ),
          "help"   => HelpKdump("SMTPPassword")
        },
        "NotificationTo"         => {
          #TRANSLATORS: TextEntry Label
          "label"         => _("Notification &To"),
          "widget"        => :textentry,
          "init"          => fun_ref(
            method(:InitNotificationTo),
            "void (string)"
          ),
          "validate_type" => :function,
          #"validate_function": ValidEmail,
          "store"         => fun_ref(
            method(:StoreNotificationTo),
            "void (string, map)"
          ),
          "help"          => HelpKdump("NotificationTo")
        },
        "NotificationCC"         => {
          #TRANSLATORS: TextEntry Label
          "label"         => _("Notifica&tion CC"),
          "widget"        => :textentry,
          "init"          => fun_ref(
            method(:InitNotificationCC),
            "void (string)"
          ),
          "validate_type" => :function,
          #"validate_function": ValidEmail,
          "store"         => fun_ref(
            method(:StoreNotificationCC),
            "void (string, map)"
          ),
          "help"          => HelpKdump("NotificationCC")
        },
        #---------============ Expert Settings screen=============------------
        "InitrdKernel"           => {
          #TRANSLATORS: TextEntry Label
          "label"  => _("Custom Kdump &Kernel"),
          "widget" => :textentry,
          "init"   => fun_ref(method(:InitInitrdKernel), "void (string)"),
          #"handle"		:
          "store"  => fun_ref(
            method(:StoreInitrdKernel),
            "void (string, map)"
          ),
          "help"   => HelpKdump("InitrdKernel")
        },
        "KdumpCommandLine"       => {
          #TRANSLATORS: TextEntry Label
          "label"  => _("Kdump Co&mmand Line"),
          "widget" => :textentry,
          "init"   => fun_ref(method(:InitKdumpCommandLine), "void (string)"),
          #"handle"		:
          "store"  => fun_ref(
            method(:StoreKdumpCommandLine),
            "void (string, map)"
          ),
          "help"   => HelpKdump("KdumpCommandLine")
        },
        "KdumpCommandLineAppend" => {
          #TRANSLATORS: TextEntry Label
          "label"  => _(
            "Kdump Command &Line Append"
          ),
          "widget" => :textentry,
          "init"   => fun_ref(
            method(:InitKdumpCommandLineAppend),
            "void (string)"
          ),
          #"handle"		:
          "store"  => fun_ref(
            method(:StoreKdumpCommandLineAppend),
            "void (string, map)"
          ),
          "help"   => HelpKdump("KdumpCommandLineAppend")
        },
        "EnableReboot"           => {
          #TRANSLATORS: CheckBox Label
          "label"  => _(
            "&Enable Immediate Reboot After Saving the Core"
          ),
          "widget" => :checkbox,
          "init"   => fun_ref(method(:InitEnableReboot), "void (string)"),
          #"handle"		:
          "store"  => fun_ref(
            method(:StoreEnableReboot),
            "void (string, map)"
          ),
          "help"   => HelpKdump("EnableReboot")
        },
        "EnableCopyKernel"       => {
          #TRANSLATORS: CheckBox Label
          "label"  => _(
            "Enable Copy Ke&rnel into the Dump Directory"
          ),
          "widget" => :checkbox,
          "init"   => fun_ref(method(:InitEnableCopyKernel), "void (string)"),
          #"handle"		:
          "store"  => fun_ref(
            method(:StoreEnableCopyKernel),
            "void (string, map)"
          ),
          "help"   => HelpKdump("EnableCopyKernel")
        },
        "EnableDeleteImages"     => {
          #TRANSLATORS: CheckBox Label
          "label"  => _(
            "Enable &Delete Old Dump Images"
          ),
          "widget" => :checkbox,
          "init"   => fun_ref(method(:InitEnableDeleteImages), "void (string)"),
          "handle" => fun_ref(
            method(:HandleEnableDeleteImages),
            "symbol (string, map)"
          ),
          "store"  => fun_ref(
            method(:StoreEnableDeleteImages),
            "void (string, map)"
          ),
          "help"   => HelpKdump("EnableDeleteImages")
        },
        "NumberDumps"            => {
          #TRANSLATORS: IntField Label
          "label"   => _("N&umber of Old Dumps"),
          "widget"  => :intfield,
          "minimum" => 0,
          "maximum" => 10,
          "init"    => fun_ref(method(:InitNumberDumps), "void (string)"),
          #"handle"		:
          "store"   => fun_ref(
            method(:StoreNumberDumps),
            "void (string, map)"
          ),
          "help"    => HelpKdump("NumberDumps")
        }
      }

      @tabs = {
        "start_up"           => {
          "contents"        => VBox(
            "EnableDisalbeKdump",
            VSpacing(1),
            Left(ReplacePoint(Id("FADump"), Empty())),
            Frame(
              _("Kdump Memory"),
              HBox(HSpacing(1), VBox(Left("KdumpMemory")))
            ),
            VStretch()
          ),
          "caption"         => _("Kdump Start-Up"),
          "tree_item_label" => _("Start-Up"),
          "widget_names"    => [
            "DisBackButton",
            "EnableDisalbeKdump",
            (Kdump.fadump_supported? ? "FADump":""),
            "KdumpMemory"
          ]
        },
        "dump_filtering"     => {
          "contents"        => VBox(
            "DumpLevel",
            VSpacing(1),
            "DumpFormat",
            VStretch()
          ),
          "caption"         => _("Kdump - Dump Filtering"),
          "tree_item_label" => _("Dump Filtering"),
          "widget_names"    => ["DisBackButton", "DumpLevel", "DumpFormat"]
        },
        "dump_target"        => {
          "contents"        => VBox(
            Frame(
              _("Saving Target for Kdump Image"),
              HBox(HSpacing(1), VBox(Left("TargetKdump")))
            ),
            VSpacing(1),
            ReplacePoint(Id("Targets"), @ftp),
            VStretch()
          ),
          "caption"         => _("Dump Target"),
          "tree_item_label" => _("Dump Target"),
          "widget_names"    => ["DisBackButton", "TargetKdump"]
        },
        "email_notification" => {
          "contents"        => VBox(
            Frame(
              _("SMTP Server"),
              HBox(
                HSpacing(1),
                VBox(
                  Left("SMTPServer"),
                  HBox("SMTPUser", HSpacing(1), "SMTPPassword", HStretch())
                )
              )
            ),
            Frame(
              _("Notification Email Addresses"),
              HBox(
                HSpacing(1),
                VBox(Left("NotificationTo"), Left("NotificationCC"))
              )
            ),
            VStretch()
          ),
          "caption"         => _("Email Notification"),
          "tree_item_label" => _("Email Notification"),
          "widget_names"    => [
            "DisBackButton",
            "SMTPServer",
            "SMTPUser",
            "SMTPPassword",
            "NotificationTo",
            "NotificationCC"
          ]
        },
        "exp_settings"       => {
          "contents"        => VBox(
            Frame(
              _("Custom Kernel for Kdump"),
              HBox(HSpacing(1), VBox(Left("InitrdKernel")))
            ),
            VSpacing(1),
            Frame(
              _("Command Line"),
              HBox(
                HSpacing(1),
                VBox(Left("KdumpCommandLine"), Left("KdumpCommandLineAppend"))
              )
            ),
            VSpacing(1),
            Frame(
              _("Dump Settings"),
              HBox(
                HSpacing(1),
                VBox(
                  Left("EnableDeleteImages"),
                  Left("NumberDumps"),
                  Left("EnableReboot"),
                  Left("EnableCopyKernel")
                )
              )
            ),
            VStretch()
          ),
          "caption"         => _("Kdump Expert Settings"),
          "tree_item_label" => _("Expert Settings"),
          "widget_names"    => [
            "DisBackButton",
            "KdumpCommandLine",
            "KdumpCommandLineAppend",
            "EnableDeleteImages",
            "NumberDumps",
            "InitrdKernel",
            "SelectKernel",
            "EnableReboot",
            "EnableCopyKernel"
          ]
        }
      }
    end

    def DisBackButton(key)
      Wizard.SetTitleIcon("yast-kdump")
      UI.ChangeWidget(Id(:back), :Enabled, false)

      nil
    end

    def RunKdumpDialogs
      sim_dialogs = [
        "start_up",
        "dump_filtering",
        "dump_target",
        "email_notification",
        "exp_settings"
      ]

      DialogTree.ShowAndRun(
        #"functions"	: " ",
        {
          #return CWMTab::CreateWidget($[
          "ids_order"      => sim_dialogs,
          "initial_screen" => "start_up",
          "screens"        => @tabs,
          "widget_descr"   => @wid_handling,
          "back_button"    => "",
          "abort_button"   => Label.CancelButton,
          "next_button"    => Label.OKButton
        }
      )
    end
  end
end
