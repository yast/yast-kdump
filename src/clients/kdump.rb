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

# File:	clients/kdump.ycp
# Package:	Configuration of kdump
# Summary:	Main file
# Authors:	Jozef Uhliarik <juhliarik@suse.com>
#
# $Id: kdump.ycp 27914 2006-02-13 14:32:08Z locilka $
#
# Main file for kdump configuration. Uses all other files.
module Yast
  class KdumpClient < Client
    def main
      Yast.import "UI"

      #**
      # <h3>Configuration of kdump</h3>

      textdomain "kdump"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Kdump module started")

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Summary"
      Yast.import "Popup"
      Yast.import "String"
      Yast.import "FileUtils"

      Yast.import "CommandLine"
      Yast.include self, "kdump/wizards.rb"

      Yast.include self, "kdump/uifunctions.rb"

      @cmdline_description = {
        "id"         => "kdump",
        # Command line help text for the kdump module
        "help"       => _(
          "Configuration of kdump"
        ),
        "guihandler" => fun_ref(method(:KdumpSequence), "any ()"),
        "initialize" => fun_ref(Kdump.method(:Read), "boolean ()"),
        "finish"     => fun_ref(Kdump.method(:Write), "boolean ()"),
        "actions"    => {
          "show"                    => {
            "handler" => fun_ref(method(:cmdKdumpShow), "boolean (map)"),
            # TRANSLATORS: CommandLine help
            "help"    => _("Display settings"),
            "example" => ["show"]
          },
          "startup"                 => {
            "handler" => fun_ref(method(:cmdKdumpStartup), "boolean (map)"),
            # TRANSLATORS: CommandLine help
            "help"    => _("Start-up settings"),
            "example" => ["startup enable alloc_mem=128,256", "startup disable"]
          },
          "dumplevel"               => {
            "handler" => fun_ref(method(:cmdKdumpDumpLevel), "boolean (map)"),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "Dump Level number 0-31"
            ),
            "example" => ["dumplevel dump_level=24"]
          },
          "dumpformat"              => {
            "handler" => fun_ref(method(:cmdKdumpDumpFormat), "boolean (map)"),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "Dump format for dump image none/ELF/compressed/lzo"
            ),
            "example" => [
              "dumpformat dump_format=none",
              "dumpformat dump_format=ELF",
              "dumpformat dump_format=compressed",
              "dumpformat dump_format=lzo"
            ]
          },
          "dumptarget"              => {
            "handler" => fun_ref(method(:cmdKdumpDumpTarget), "boolean (map)"),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "Dump target includes destination for saving dump images"
            ),
            "example" => [
              "dumptarget taget=file dir=/var/log/dump",
              "dumptarget taget=ftp server=name_server port=21 dir=/var/log/dump user=user_name pass=path_to_file_with_password",
              "dumptarget taget=ssh server=name_server port=22 dir=/var/log/dump user=user_name",
              "dumptarget taget=sftp server=name_server port=22 dir=/var/log/dump user=user_name",
              "dumptarget taget=nfs server=name_server dir=/var/log/dump",
              "dumptarget taget=cifs server=name_server share=share_name dir=/var/log/dump user=user_name pass=path_to_file_with_password"
            ]
          },
          "customkernel"            => {
            "handler" => fun_ref(method(:cmdKdumpCustomKernel), "boolean (map)"),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "The naming scheme is:/boot/vmlinu[zx]-<kernel_string>[.gz] Please enter only \"kernel_string\"."
            ),
            "example" => ["customkernel kernel=kdump"]
          },
          "kernelcommandline"       => {
            "handler" => fun_ref(
              method(:cmdKdumpKernelCommandLine),
              "boolean (map)"
            ),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "The kdump commandline is the command line that needs to be passed off to the kdump kernel."
            ),
            "example" => ["kernelcommandline command=\"ro root=LABEL=/\""]
          },
          "kernelcommandlineappend" => {
            "handler" => fun_ref(
              method(:cmdKdumpKernelCommandLineAppend),
              "boolean (map)"
            ),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "Set this variable if you only want to _append_ values to the default command line string."
            ),
            "example" => ["kernelcommandlineapped command=\"ro root=LABEL=/\""]
          },
          "immediatereboot"         => {
            "handler" => fun_ref(
              method(:cmdKdumpImmediateReboot),
              "boolean (map)"
            ),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "Immediately reboot after saving the core in the kdump kernel."
            ),
            "example" => ["immediatereboot enable", "immediatereboot disable"]
          },
          "copykernel"              => {
            "handler" => fun_ref(method(:cmdKdumpCopyKernel), "boolean (map)"),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "Copy kernel into dump directory."
            ),
            "example" => ["copykernel enable", "copykernel disable"]
          },
          "keepolddumps"            => {
            "handler" => fun_ref(method(:cmdKdumpKeepOldDumps), "boolean (map)"),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "Specifies how many old dumps are kept. 0 means keep all."
            ),
            "example" => ["keepolddumps no=5"]
          },
          "smtpserver"              => {
            "handler" => fun_ref(method(:cmdKdumpSMTPServer), "boolean (map)"),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "SMTP server for sending notification messages."
            ),
            "example" => ["smtpserver server=smtp.server.com"]
          },
          "smtpuser"                => {
            "handler" => fun_ref(method(:cmdKdumpSMTPUser), "boolean (map)"),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "SMTP username for sending notification messages."
            ),
            "example" => ["smtpuser user=foo_user"]
          },
          "smtppass"                => {
            "handler" => fun_ref(method(:cmdKdumpSMTPPass), "boolean (map)"),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "SMTP password for sending notification messages. Path of file which includes password (plain text file)."
            ),
            "example" => ["smtppass pass=/path/to/file"]
          },
          "notificationto"          => {
            "handler" => fun_ref(method(:cmdKdumpSMTPNotifTo), "boolean (map)"),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "Email address for sending notification messages"
            ),
            "example" => [
              "notificationto email=foo@bar.com",
              "notificationto email=\"foo1@bar.com foo2@bar.com\""
            ]
          },
          "notificationcc"          => {
            "handler" => fun_ref(method(:cmdKdumpSMTPNotifCC), "boolean (map)"),
            # TRANSLATORS: CommandLine help
            "help"    => _(
              "Email address for sending copy of notification messages"
            ),
            "example" => [
              "notificationcc email=foo@bar.com",
              "notificationcc email=\"foo1@bar.com foo2@bar.com\""
            ]
          }
        },
        "options"    => {
          "enable"      => {
            # TRANSLATORS: CommandLine help
            "help" => _("Enable option")
          },
          "disable"     => {
            # TRANSLATORS: CommandLine help
            "help" => _("Disable option")
          },
          "status"      => {
            # TRANSLATORS: CommandLine help
            "help" => _("Shows current option status")
          },
          "alloc_mem"   => {
            "type" => "string",
            # TRANSLATORS: CommandLine help
            "help" => _(
              "Allocate Low and High Memory (in MB) of Kdump separated by comma"
            )
          },
          "dump_level"  => {
            "type" => "integer",
            # TRANSLATORS: CommandLine help
            "help" => _(
              "Number for dump level includes pages for saving"
            )
          },
          "dump_format" => {
            "type" => "string",
            # TRANSLATORS: CommandLine help
            "help" => _(
              "Dump format can be none, ELF, compressed or lzo"
            )
          },
          "target"      => {
            "type" => "string",
            # TRANSLATORS: CommandLine help
            "help" => _(
              "Dump target includes type of target from: file (local filesystem), ftp, ssh, sftp, nfs, cifs"
            )
          },
          "server"      => {
            "type" => "string",
            # TRANSLATORS: CommandLine help
            "help" => _("Name of server")
          },
          "port"        => {
            "type" => "integer",
            # TRANSLATORS: CommandLine help
            "help" => _("Port for connection")
          },
          "dir"         => {
            "type" => "string",
            # TRANSLATORS: CommandLine help
            "help" => _(
              "Directory for saving dump images"
            )
          },
          "share"       => {
            "type" => "string",
            # TRANSLATORS: CommandLine help
            "help" => _("Exported share")
          },
          "user"        => {
            "type" => "string",
            # TRANSLATORS: CommandLine help
            "help" => _("User name")
          },
          "pass"        => {
            "type" => "string",
            # TRANSLATORS: CommandLine help
            "help" => _(
              "Path of file which includes password (plain text file)"
            )
          },
          "raw"         => {
            "type" => "string",
            # TRANSLATORS: CommandLine help
            "help" => _(
              "udev_id of raw partition"
            )
          },
          "kernel"      => {
            "type" => "string",
            # TRANSLATORS: CommandLine help
            "help" => _(
              "The naming scheme is: /boot/vmlinu[zx]-<kernel_string>[.gz] kernel means only \"kernel_string\"."
            )
          },
          "command"     => {
            "type" => "string",
            # TRANSLATORS: CommandLine help
            "help" => _(
              "Include command line options."
            )
          },
          "level"       => {
            "type" => "string",
            # TRANSLATORS: CommandLine help
            "help" => _(
              "Option means runlevel to boot the kdump kernel. Only values such as 1,2,3,5 or s are allowed"
            )
          },
          "no"          => {
            "type" => "integer",
            # TRANSLATORS: CommandLine help
            "help" => _(
              "Number of dumps. 0 means keep all."
            )
          },
          "email"       => {
            "type" => "string",
            # TRANSLATORS: CommandLine help
            "help" => _("Email address")
          }
        },
        "mappings"   => {
          "show"                    => [],
          "startup"                 => ["enable", "disable", "alloc_mem"],
          "dumplevel"               => ["dump_level"],
          "dumpformat"              => ["dump_format"],
          "dumptarget"              => [
            "target",
            "server",
            "port",
            "share",
            "dir",
            "user",
            "pass"
          ],
          "customkernel"            => ["kernel"],
          "kernelcommandline"       => ["command"],
          "kernelcommandlineappend" => ["command"],
          "immediatereboot"         => ["enable", "disable"],
          "keepolddumps"            => ["no"],
          "smtpserver"              => ["server"],
          "smtpuser"                => ["user"],
          "smtppass"                => ["pass"],
          "notificationto"          => ["email"],
          "notificationcc"          => ["email"]
        }
      }

      if Kdump.system.supports_fadump?
        @cmdline_description["actions"]["fadump"] = {
          "handler" => fun_ref(method(:cmd_handle_fadump), "boolean (map)"),
          # TRANSLATORS: CommandLine help
          "help" => _(
            "Handles usage of firmware-assisted dump"
          ),
          "example" => [
            "fadump status  # shows the current status (enabled/disabled)",
            "fadump enable  # enables using fadump",
            "fadump disable # disables using fadump",
          ],
        }

        @cmdline_description["mappings"]["fadump"] = ["enable", "disable", "status"]
      end

      # is this proposal or not?
      @propose = false
      @args = WFM.Args
      if Ops.greater_than(Builtins.size(@args), 0)
        if Ops.is_path?(WFM.Args(0)) && WFM.Args(0) == path(".propose")
          Builtins.y2milestone("Using PROPOSE mode")
          @propose = true
        end
      end

      # main ui function
      @ret = nil

      if @propose
        #ret = KdumpAutoSequence();
        Popup.Error("AutoYaST is not supported")
        @ret = :abort
      else
        @ret = CommandLine.Run(@cmdline_description)
      end
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Kdump module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end

    # Command line function for display options from kdump
    #
    def cmdKdumpShow(options)
      options = deep_copy(options)
      CommandLine.Print("")
      #TRANSLATORS: CommandLine printed text
      CommandLine.Print(String.UnderlinedHeader(_("Display Settings:"), 0))
      CommandLine.Print("")
      if Kdump.crashkernel_param
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(
          _("Kdump is enabled (boot option \"crashkernel\" is added)")
        )
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(
          Builtins.sformat(
            _("Allocate memory (MB) for kdump is: %1"),
            Kdump.allocated_memory
          )
        )
      else
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(_("Kdump is disabled"))
      end
      CommandLine.Print("")
      #TRANSLATORS: CommandLine printed text
      CommandLine.Print(
        Builtins.sformat(
          _("Dump Level: %1"),
          Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_DUMPLEVEL")
        )
      )
      CommandLine.Print("")
      #TRANSLATORS: CommandLine printed text
      CommandLine.Print(
        Builtins.sformat(
          _("Dump Format: %1"),
          Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_DUMPFORMAT")
        )
      )
      CommandLine.Print("")

      # parsing target info
      CommandLine.Print(_("Dump Target Settings"))
      if SetUpKDUMP_SAVE_TARGET(Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_SAVEDIR"))
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(
          Builtins.sformat(
            _("target: %1"),
            Ops.get(@KDUMP_SAVE_TARGET, "target")
          )
        )

        #local filesystem
        if Ops.get(@KDUMP_SAVE_TARGET, "target") == "file"
          #TRANSLATORS: CommandLine printed text
          CommandLine.Print(
            Builtins.sformat(
              _("file directory: %1"),
              Ops.get(@KDUMP_SAVE_TARGET, "dir")
            )
          ) 

          #ftp target
        elsif Ops.get(@KDUMP_SAVE_TARGET, "target") == "ftp"
          #TRANSLATORS: CommandLine printed text
          CommandLine.Print(
            Builtins.sformat(
              _("server name: %1"),
              Ops.get(@KDUMP_SAVE_TARGET, "server")
            )
          )

          if Ops.get(@KDUMP_SAVE_TARGET, "port") != ""
            #TRANSLATORS: CommandLine printed text
            CommandLine.Print(
              Builtins.sformat(
                _("port: %1"),
                Ops.get(@KDUMP_SAVE_TARGET, "port")
              )
            )
          end
          #TRANSLATORS: CommandLine printed text
          CommandLine.Print(
            Builtins.sformat(
              _("file directory: %1"),
              Ops.get(@KDUMP_SAVE_TARGET, "dir")
            )
          )

          if Ops.get(@KDUMP_SAVE_TARGET, "user_name") == "" ||
              Ops.get(@KDUMP_SAVE_TARGET, "user_name") == "anonymous"
            #TRANSLATORS: CommandLine printed text
            CommandLine.Print(_("user name: anonymous connection is allowed"))
          else
            #TRANSLATORS: CommandLine printed text
            CommandLine.Print(
              Builtins.sformat(
                _("user name: %1"),
                Ops.get(@KDUMP_SAVE_TARGET, "user_name")
              )
            )
          end 

          #ssh/sftp connection
        elsif ["ssh", "sftp"].include?(@KDUMP_SAVE_TARGET["target"])
          #TRANSLATORS: CommandLine printed text
          CommandLine.Print(
            Builtins.sformat(
              _("server name: %1"),
              Ops.get(@KDUMP_SAVE_TARGET, "server")
            )
          )


          if Ops.get(@KDUMP_SAVE_TARGET, "port") != ""
            #TRANSLATORS: CommandLine printed text
            CommandLine.Print(
              Builtins.sformat(
                _("port: %1"),
                Ops.get(@KDUMP_SAVE_TARGET, "port")
              )
            )
          end

          #TRANSLATORS: CommandLine printed text
          CommandLine.Print(
            Builtins.sformat(
              _("file directory: %1"),
              Ops.get(@KDUMP_SAVE_TARGET, "dir")
            )
          )

          if Ops.get(@KDUMP_SAVE_TARGET, "user_name") != "" &&
              Ops.get(@KDUMP_SAVE_TARGET, "user_name") != "anonymous"
            #TRANSLATORS: CommandLine printed text
            CommandLine.Print(
              Builtins.sformat(
                _("user name: %1"),
                Ops.get(@KDUMP_SAVE_TARGET, "user_name")
              )
            )
          end 

          # nfs target
        elsif Ops.get(@KDUMP_SAVE_TARGET, "target") == "nfs"
          #TRANSLATORS: CommandLine printed text
          CommandLine.Print(
            Builtins.sformat(
              _("server name: %1"),
              Ops.get(@KDUMP_SAVE_TARGET, "server")
            )
          )
          #TRANSLATORS: CommandLine printed text
          CommandLine.Print(
            Builtins.sformat(
              _("file directory: %1"),
              Ops.get(@KDUMP_SAVE_TARGET, "dir")
            )
          ) 

          #cifs target
        elsif Ops.get(@KDUMP_SAVE_TARGET, "target") == "cifs"
          #TRANSLATORS: CommandLine printed text
          CommandLine.Print(
            Builtins.sformat(
              _("server name: %1"),
              Ops.get(@KDUMP_SAVE_TARGET, "server")
            )
          )
          #TRANSLATORS: CommandLine printed text
          CommandLine.Print(
            Builtins.sformat(
              _("file directory: %1"),
              Ops.get(@KDUMP_SAVE_TARGET, "dir")
            )
          )
          #TRANSLATORS: CommandLine printed text
          CommandLine.Print(
            Builtins.sformat(
              _("share: %1"),
              Ops.get(@KDUMP_SAVE_TARGET, "share")
            )
          )

          if Ops.get(@KDUMP_SAVE_TARGET, "user_name") == "" ||
              Ops.get(@KDUMP_SAVE_TARGET, "user_name") == "anonymous"
            #TRANSLATORS: CommandLine printed text
            CommandLine.Print(_("user name: anonymous connection is allowed"))
          else
            #TRANSLATORS: CommandLine printed text
            CommandLine.Print(
              Builtins.sformat(
                _("user name: %1"),
                Ops.get(@KDUMP_SAVE_TARGET, "user_name")
              )
            )
          end
        end
      else
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(_("EMPTY"))
      end #end of if (SetUpKDUMP_SAVE_TARGET(Kdump::KDUMP_SETTINGS["KDUMP_SAVEDIR"]:nil))

      if Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_KERNELVER") != ""
        CommandLine.Print("")
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(
          Builtins.sformat(
            _("Custom kdump kernel: %1"),
            Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_KERNELVER")
          )
        )
      end

      if Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_COMMANDLINE") != ""
        CommandLine.Print("")
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(
          Builtins.sformat(
            _("Kdump command line: %1"),
            Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_COMMANDLINE")
          )
        )
      end

      if Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_COMMANDLINE_APPEND") != ""
        CommandLine.Print("")
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(
          Builtins.sformat(
            _("Kdump command line append: %1"),
            Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_COMMANDLINE_APPEND")
          )
        )
      end

      CommandLine.Print("")
      #TRANSLATORS: CommandLine printed text
      CommandLine.Print(
        Builtins.sformat(
          _("Kdump immediate reboots: %1"),
          Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_IMMEDIATE_REBOOT") == "yes" ?
            _("Enabled") :
            _("Disabled")
        )
      )

      CommandLine.Print("")

      if Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_KEEP_OLD_DUMPS") == "0"
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(
          _(
            "Numbers of old dumps: All dumps are saved without deleting old dumps"
          )
        )
      else
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(
          Builtins.sformat(
            _("Numbers of old dumps: %1"),
            Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_KEEP_OLD_DUMPS")
          )
        )
      end

      if Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_SMTP_SERVER", "") != ""
        CommandLine.Print("")
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(
          Builtins.sformat(
            _("Kdump SMTP Server: %1"),
            Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_SMTP_SERVER")
          )
        )
      end

      if Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_SMTP_USER", "") != ""
        CommandLine.Print("")
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(
          Builtins.sformat(
            _("Kdump SMTP User: %1"),
            Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_SMTP_USER")
          )
        )
      end

      if Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_SMTP_PASSWORD", "") != ""
        CommandLine.Print("")
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(_("Kdump SMTP Password: ********"))
      end

      if Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_NOTIFICATION_TO", "") != ""
        CommandLine.Print("")
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(
          Builtins.sformat(
            _("Kdump Sending Notification To: %1"),
            Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_NOTIFICATION_TO", "")
          )
        )
      end

      if Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_NOTIFICATION_CC", "") != ""
        CommandLine.Print("")
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(
          Builtins.sformat(
            _("Kdump Sending Copy of Notification To: %1"),
            Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_NOTIFICATION_CC", "")
          )
        )
      end

      CommandLine.Print("")

      if Kdump.system.supports_fadump?
        show_fadump_status
        CommandLine.Print("")
      end

      true
    end


    # Only numbers are allowed as allow_mem_high and allow_mem_low values
    ALLOC_MEM_REGEXP = /\A\d+\z/

    def cmdKdumpStartup(options)
      options = deep_copy(options)
      if Ops.get(options, "enable") != nil &&
          Ops.get(options, "alloc_mem") != nil
        alloc_mem_low, alloc_mem_high = options["alloc_mem"].split(',')
        unless alloc_mem_low =~ ALLOC_MEM_REGEXP &&
                (alloc_mem_high.nil? || alloc_mem_high =~ ALLOC_MEM_REGEXP)
          CommandLine.Error(_("Invalid allocation memory parameter"))
          return false
        end
        Kdump.add_crashkernel_param = true
        Kdump.allocated_memory = { low: alloc_mem_low, high: alloc_mem_high }
        #TRANSLATORS: CommandLine printed text
        if Kdump.crashkernel_list_ranges
          CommandLine.Print(
            _(
              "Kernel option \"crashkernel\" includes ranges and/or redundant values.\n"\
              "It will be rewritten."
            )
          )
          # Force value to false, so it's actually rewritten
          Kdump.crashkernel_list_ranges = false
        end
        CommandLine.Print(_("To apply changes a reboot is necessary."))
        return true
      elsif Ops.get(options, "disable") != nil
        Kdump.add_crashkernel_param = false
        #TRANSLATORS: CommandLine printed text
        CommandLine.Print(_("To apply changes a reboot is necessary."))
        return true
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end


    def cmdKdumpDumpLevel(options)
      options = deep_copy(options)
      if Ops.get(options, "dump_level") != nil
        if Ops.less_than(Ops.get(options, "dump_level"), 32) &&
            Ops.greater_than(Ops.get(options, "dump_level"), -1)
          Ops.set(
            Kdump.KDUMP_SETTINGS,
            "KDUMP_DUMPLEVEL",
            Builtins.tostring(Ops.get(options, "dump_level"))
          )
          #TRANSLATORS: CommandLine printed text
          CommandLine.Print(_("Dump level was set."))
          return true
        else
          # TRANSLATORS: CommandLine error message
          CommandLine.Error(_("Wrong value of option."))
          return false
        end
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end

    def cmdKdumpDumpFormat(options)
      options = deep_copy(options)
      if Ops.get(options, "dump_format") != nil
        if Ops.get(options, "dump_format") == "ELF" ||
            Ops.get(options, "dump_format") == "compressed"
          Ops.set(
            Kdump.KDUMP_SETTINGS,
            "KDUMP_DUMPFORMAT",
            Builtins.tostring(Ops.get(options, "dump_format"))
          )
          #TRANSLATORS: CommandLine printed text
          CommandLine.Print(_("Dump format was set."))
          return true
        else
          # TRANSLATORS: CommandLine error message
          CommandLine.Error(_("Wrong value of option."))
          #TRANSLATORS: CommandLine printed text help
          CommandLine.Print(
            _("Option can include only \"none\", \"ELF\", \"compressed\" or \"lzo\" value.")
          )
          return false
        end
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end

    def cmdParsePassPath(path_file)
      password = nil
      if FileUtils.IsFile(path_file)
        password = Convert.to_string(
          SCR.Read(path(".target.string"), path_file)
        )
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(
          Builtins.sformat(_("File %1 does not exist."), path_file)
        )
      end
      password
    end


    def cmdKdumpDumpTarget(options)
      options = deep_copy(options)
      if Ops.get(options, "target") != nil
        target = Builtins.tostring(Ops.get(options, "target"))
        case target
          when "file"
            Ops.set(@KDUMP_SAVE_TARGET, "target", "file")
            if Ops.get(options, "dir") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "dir",
                Builtins.tostring(Ops.get(options, "dir"))
              )
            else
              # TRANSLATORS: CommandLine error message
              CommandLine.Error(_("Value for \"dir\" missing."))
              return false
            end
          when "ftp"
            Ops.set(@KDUMP_SAVE_TARGET, "target", "ftp")

            if Ops.get(options, "server") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "server",
                Builtins.tostring(Ops.get(options, "server"))
              )
            else
              # TRANSLATORS: CommandLine error message
              CommandLine.Error(_("Value for \"server\" missing."))
              return false
            end

            if Ops.get(options, "port") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "port",
                Builtins.tostring(Ops.get(options, "port"))
              )
            end

            if Ops.get(options, "dir") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "dir",
                Builtins.tostring(Ops.get(options, "dir"))
              )
            else
              # TRANSLATORS: CommandLine error message
              CommandLine.Error(_("Value for \"dir\" missing."))
              return false
            end

            if Ops.get(options, "user") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "user_name",
                Builtins.tostring(Ops.get(options, "user"))
              )
            end

            if Ops.get(options, "pass") != nil
              password = cmdParsePassPath(
                Builtins.tostring(Ops.get(options, "pass"))
              )
              return false if password == nil || password == ""
              Ops.set(@KDUMP_SAVE_TARGET, "password", password)
            end
          when "ssh", "sftp"
            @KDUMP_SAVE_TARGET["target"] = target

            if Ops.get(options, "server") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "server",
                Builtins.tostring(Ops.get(options, "server"))
              )
            else
              # TRANSLATORS: CommandLine error message
              CommandLine.Error(_("Value for \"server\" missing."))
              return false
            end

            if Ops.get(options, "port") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "port",
                Builtins.tostring(Ops.get(options, "port"))
              )
            end

            if Ops.get(options, "dir") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "dir",
                Builtins.tostring(Ops.get(options, "dir"))
              )
            else
              CommandLine.Error(_("Value for \"dir\" missing."))
              return false
            end

            if Ops.get(options, "user") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "user_name",
                Builtins.tostring(Ops.get(options, "user"))
              )
            end
          when "nfs"
            Ops.set(@KDUMP_SAVE_TARGET, "target", "nfs")

            if Ops.get(options, "server") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "server",
                Builtins.tostring(Ops.get(options, "server"))
              )
            else
              # TRANSLATORS: CommandLine error message
              CommandLine.Error(_("Value for \"server\" missing."))
              return false
            end

            if Ops.get(options, "dir") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "dir",
                Builtins.tostring(Ops.get(options, "dir"))
              )
            else
              # TRANSLATORS: CommandLine error message
              CommandLine.Error(_("Value for \"dir\" missing."))
              return false
            end
          when "cifs"
            Ops.set(@KDUMP_SAVE_TARGET, "target", "cifs")

            if Ops.get(options, "server") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "server",
                Builtins.tostring(Ops.get(options, "server"))
              )
            else
              # TRANSLATORS: CommandLine error message
              CommandLine.Error(_("Value for \"server\" missing."))
              return false
            end

            if Ops.get(options, "share") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "share",
                Builtins.tostring(Ops.get(options, "share"))
              )
            else
              # TRANSLATORS: CommandLine error message
              CommandLine.Error(_("Value for \"share\" missing."))
              return false
            end


            if Ops.get(options, "port") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "port",
                Builtins.tostring(Ops.get(options, "port"))
              )
            end

            if Ops.get(options, "dir") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "dir",
                Builtins.tostring(Ops.get(options, "dir"))
              )
            else
              # TRANSLATORS: CommandLine error message
              CommandLine.Error(_("Value for \"dir\" missing."))
              return false
            end

            if Ops.get(options, "user") != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "user_name",
                Builtins.tostring(Ops.get(options, "user"))
              )
            end

            if Ops.get(options, "pass") != nil
              password = cmdParsePassPath(
                Builtins.tostring(Ops.get(options, "pass"))
              )
              return false if password == nil || password == ""
              Ops.set(@KDUMP_SAVE_TARGET, "password", password)
            end
          else
            # TRANSLATORS: CommandLine error message
            CommandLine.Error(_("Wrong value for target."))
            return false
        end
        Ops.set(
          Kdump.KDUMP_SETTINGS,
          "KDUMP_SAVEDIR",
          tostringKDUMP_SAVE_TARGET
        )
        return true
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end


    def cmdKdumpCustomKernel(options)
      options = deep_copy(options)
      if Ops.get(options, "kernel") != nil
        Ops.set(
          Kdump.KDUMP_SETTINGS,
          "KDUMP_KERNELVER",
          Builtins.tostring(Ops.get(options, "kernel"))
        )
        return true
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end


    def cmdKdumpKernelCommandLine(options)
      options = deep_copy(options)
      if Ops.get(options, "command") != nil
        Ops.set(
          Kdump.KDUMP_SETTINGS,
          "KDUMP_COMMANDLINE",
          Builtins.tostring(Ops.get(options, "command"))
        )
        return true
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end


    def cmdKdumpKernelCommandLineAppend(options)
      options = deep_copy(options)
      if Ops.get(options, "command") != nil
        Ops.set(
          Kdump.KDUMP_SETTINGS,
          "KDUMP_COMMANDLINE_APPEND",
          Builtins.tostring(Ops.get(options, "command"))
        )
        return true
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end

    def cmdKdumpImmediateReboot(options)
      options = deep_copy(options)
      if Ops.get(options, "enable") != nil
        Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_IMMEDIATE_REBOOT", "yes")
        return true
      elsif Ops.get(options, "disable") != nil
        Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_IMMEDIATE_REBOOT", "no")
        return true
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end


    def cmdKdumpCopyKernel(options)
      options = deep_copy(options)
      if Ops.get(options, "enable") != nil
        Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_COPY_KERNEL", "yes")
        return true
      elsif Ops.get(options, "disable") != nil
        Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_COPY_KERNEL", "no")
        return true
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end


    def cmdKdumpKeepOldDumps(options)
      options = deep_copy(options)
      if Ops.get(options, "no") != nil
        if Ops.greater_than(Ops.get(options, "no"), -1)
          Ops.set(
            Kdump.KDUMP_SETTINGS,
            "KDUMP_KEEP_OLD_DUMPS",
            Builtins.tostring(Ops.get(options, "no"))
          )
          return true
        else
          # TRANSLATORS: CommandLine error message
          CommandLine.Error(_("Wrong value of options \"no\"."))
          return false
        end
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end

    def cmdKdumpSMTPServer(options)
      options = deep_copy(options)
      if Ops.get(options, "server") != nil
        server = Builtins.tostring(Ops.get(options, "server"))

        if server != "" && server != nil
          Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_SMTP_SERVER", server)
          return true
        else
          # TRANSLATORS: CommandLine error message
          CommandLine.Error(_("Wrong value for option \"server\"."))
          return false
        end
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end

    def cmdKdumpSMTPUser(options)
      options = deep_copy(options)
      if Ops.get(options, "user") != nil
        user = Builtins.tostring(Ops.get(options, "user"))

        if user != "" && user != nil
          Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_SMTP_USER", user)
          return true
        else
          # TRANSLATORS: CommandLine error message
          CommandLine.Error(_("Wrong value for option \"user\"."))
          return false
        end
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end


    def cmdKdumpSMTPPass(options)
      options = deep_copy(options)
      if Ops.get(options, "pass") != nil
        password = cmdParsePassPath(Builtins.tostring(Ops.get(options, "pass")))
        return false if password == nil || password == ""
        Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_SMTP_PASSWORD", password)
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end

      nil
    end


    def cmdKdumpSMTPNotifTo(options)
      options = deep_copy(options)
      if Ops.get(options, "email") != nil
        email = Builtins.tostring(Ops.get(options, "email"))

        if email != "" && email != nil
          Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_NOTIFICATION_TO", email)
          return true
        else
          # TRANSLATORS: CommandLine error message
          CommandLine.Error(_("Wrong value for option \"email\"."))
          return false
        end
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end

    def cmdKdumpSMTPNotifCC(options)
      options = deep_copy(options)
      if Ops.get(options, "email") != nil
        email = Builtins.tostring(Ops.get(options, "email"))

        if email != "" && email != nil
          Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_NOTIFICATION_CC", email)
          return true
        else
          # TRANSLATORS: CommandLine error message
          CommandLine.Error(_("Wrong value for option \"email\"."))
          return false
        end
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("Wrong options were used."))
        return false
      end
    end

    def show_fadump_status
      CommandLine.Print(
        _("Firmware-assisted dump: %{status}") %
          { :status => Kdump.using_fadump? ?
            _("Enabled") :
            _("Disabled")
          }
      )
    end

    def cmd_handle_fadump(options)
      if options["enable"]
        return Kdump.use_fadump(true)
      elsif options["disable"]
        return Kdump.use_fadump(false)
      elsif options["status"]
        show_fadump_status
        return true
      else
        # TRANSLATORS: CommandLine error message
        CommandLine.Error(_("No option has been defined."))
        return false
      end
    end

  end
end

Yast::KdumpClient.new.main
