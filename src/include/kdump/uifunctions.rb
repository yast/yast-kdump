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
  module KdumpUifunctionsInclude
    def initialize_kdump_uifunctions(include_target)
      textdomain "kdump"

      Yast.import "Popup"
      Yast.import "Kdump"
      Yast.import "Service"
      Yast.import "Package"
      Yast.import "PackageSystem"
      Yast.import "Mode"

      # EXAMPLE FUNCTIONS
      #    void ExampleInit(string key) {
      #	y2milestone("Example Init");
      #    }
      #
      #    symbol ExampleHandle(string key, map event) {
      #	any ret = event["ID"]:nil;
      #	y2milestone("Example Handle");
      #	return nil;
      #    }
      #
      #    void ExampleStore(string key, map event) {
      #	any ret = event["ID"]:nil;
      #	y2milestone("Example Store");
      #    }
      #


      @set_network = false

      @set_kdump_append = false

      # map of values for "KDUMP_SAVEDIR"
      #
      # local map <string, string >
      @KDUMP_SAVE_TARGET = {
        "target"    => "file", # ftp, ssh, nfs, cifs
        "server"    => "",
        "dir"       => "",
        "user_name" => "", # empty means anonymous
        "port"      => "", # deafults ftp: 21 ssh:22
        "share"     => "",
        "password"  => ""
      }

      @type = "local_filesystem"

      # definition UI terms for saveing dump target
      #
      # terms

      @local_filesystem = VBox(
        Frame(
          _("Local Filesystem"),
          HBox(
            HSpacing(1),
            VBox(
              Left(
                HBox(
                  InputField(Id("dir"), _("&Directory for Saving Dumps")),
                  VBox(
                    Label(""),
                    PushButton(Id("select_dir"), _("B&rowse"))
                  )
                )
              )
            )
          )
        )
      )


      @ftp = VBox(
        Frame(
          _("FTP"),
          HBox(
            HSpacing(1),
            VBox(
              Left(
                HBox(
                  Left(InputField(Id("server"), _("Server Nam&e"))),
                  HSpacing(1),
                  Left(IntField(Id("port"), _("P&ort"), 0, 65536, 21)),
                  HStretch()
                )
              ),
              # text entry
              Left(InputField(Id("dir"), _("&Directory on Server"))),
              Left(
                CheckBox(
                  Id("anonymous"),
                  Opt(:notify),
                  _("Enable Anon&ymous FTP")
                )
              ),
              Left(
                HBox(
                  # text entry
                  Left(InputField(Id("user_name"), _("&User Name"))),
                  HSpacing(1),
                  # password entry
                  Left(Password(Id("password"), _("&Password")))
                )
              )
            )
          )
        )
      )

      @ssh = VBox(
        Frame(
          _("SSH / SFTP"),
          HBox(
            HSpacing(1),
            VBox(
              Left(
                HBox(
                  Left(InputField(Id("server"), _("Server Nam&e"))),
                  HSpacing(1),
                  Left(IntField(Id("port"), _("P&ort"), 0, 65536, 22)),
                  HStretch()
                )
              ),
              Left(InputField(Id("dir"), _("&Directory on Server"))),
              # text entry
              Left(
                HBox(
                  # text entry
                  Left(InputField(Id("user_name"), _("&User Name"))),
                  HSpacing(1),
                  # password entry
                  Left(Password(Id("password"), _("&Password")))
                )
              )
            )
          )
        )
      )

      @nfs = VBox(
        Frame(
          _("NFS"),
          HBox(
            HSpacing(1),
            VBox(
              Left(InputField(Id("server"), _("Server Nam&e"))),
              # text entry
              Left(InputField(Id("dir"), _("&Directory on Server")))
            )
          )
        )
      )


      @cifs = VBox(
        Frame(
          _("CIFS (SMB)"),
          HBox(
            HSpacing(1),
            VBox(
              Left(InputField(Id("server"), _("Server Nam&e"))),
              Left(
                HBox(
                  # text entries
                  Left(InputField(Id("share"), _("Exported Sha&re"))),
                  HSpacing(1),
                  Left(InputField(Id("dir"), _("&Directory on Server")))
                )
              ),
              Left(
                CheckBox(
                  Id("anonymous"),
                  Opt(:notify),
                  _("Use Aut&hentication"),
                  true
                )
              ),
              Left(
                HBox(
                  # text entry
                  Left(InputField(Id("user_name"), _("&User Name"))),
                  HSpacing(1),
                  # password entry
                  Left(Password(Id("password"), _("&Password")))
                )
              )
            )
          )
        )
      )


      # helper list, each bit has its decimal representation
      @bit_weight_row = [16, 8, 4, 2, 1]
    end

    # Function initializes option "Enable/Disable kdump"
    def InitEnableDisalbeKdump(key)
      enable = Kdump.add_crashkernel_param
      enable &&= Service.enabled?(KdumpClass::KDUMP_SERVICE_NAME) unless Mode.installation

      value = enable ? "enable_kdump" : "disable_kdump"

      UI.ChangeWidget(Id("EnableDisalbeKdump"), :Value, value)

      nil
    end

    # Function stores option "Enable/Disable kdump"
    #
    def StoreEnableDisalbeKdump(key, event)
      event = deep_copy(event)
      radiobut = Convert.to_string(
        UI.QueryWidget(Id("EnableDisalbeKdump"), :Value)
      )
      if radiobut == "enable_kdump"
        Kdump.add_crashkernel_param = true
      else
        Kdump.add_crashkernel_param = false
      end

      nil
    end

    # Function for handling map values
    #
    # local map <string, string > KDUMP_SAVE_TARGET

    def SetUpKDUMP_SAVE_TARGET(target)
      parse_target = target

      if target != ""
        pos = Builtins.search(parse_target, "/")
        pos1 = -1
        Ops.set(
          @KDUMP_SAVE_TARGET,
          "target",
          Builtins.substring(parse_target, 0, Ops.subtract(pos, 1))
        )
        parse_target = Builtins.substring(parse_target, Ops.add(pos, 2))

        # file
        if Ops.get(@KDUMP_SAVE_TARGET, "target") == "file"
          Ops.set(@KDUMP_SAVE_TARGET, "dir", parse_target) 

          # nfs
        elsif Ops.get(@KDUMP_SAVE_TARGET, "target") == "nfs"
          pos = Builtins.search(parse_target, "/")
          #pos1 = pos;
          Ops.set(
            @KDUMP_SAVE_TARGET,
            "server",
            Builtins.substring(parse_target, 0, pos)
          )
          #pos = find(parse_target, "/");
          #KDUMP_SAVE_TARGET["share"]=substring(parse_target,pos1+1,pos-(pos1+1));
          Ops.set(
            @KDUMP_SAVE_TARGET,
            "dir",
            Builtins.substring(parse_target, pos)
          )
        elsif ["ftp", "cifs", "ssh", "sftp"].include?(@KDUMP_SAVE_TARGET["target"])
          pos = Builtins.search(parse_target, "@")

          if pos != nil
            user_pas = Builtins.substring(parse_target, 0, pos)
            pos1 = Builtins.search(user_pas, ":")

            if pos1 != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "user_name",
                Builtins.substring(user_pas, 0, pos1)
              )
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "password",
                Builtins.substring(user_pas, Ops.add(pos1, 1), pos)
              )
            else
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "user_name",
                Builtins.substring(user_pas, 0, pos)
              )
            end
            parse_target = Builtins.substring(parse_target, Ops.add(pos, 1))
          end
          # only ftp & ssh
          if ["ftp", "ssh", "sftp"].include?(@KDUMP_SAVE_TARGET["target"])
            pos1 = Builtins.search(parse_target, ":")
            pos = Builtins.search(parse_target, "/")

            if pos1 != nil
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "server",
                Builtins.substring(parse_target, 0, pos1)
              )
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "port",
                Builtins.substring(
                  parse_target,
                  Ops.add(pos1, 1),
                  Ops.subtract(pos, Ops.add(pos1, 1))
                )
              )
            else
              Ops.set(
                @KDUMP_SAVE_TARGET,
                "server",
                Builtins.substring(parse_target, 0, pos)
              )
            end
            Ops.set(
              @KDUMP_SAVE_TARGET,
              "dir",
              Builtins.substring(parse_target, pos)
            ) 

            # only cifs
          else
            pos = Builtins.search(parse_target, "/")
            Ops.set(
              @KDUMP_SAVE_TARGET,
              "server",
              Builtins.substring(parse_target, 0, pos)
            )
            parse_target = Builtins.substring(parse_target, Ops.add(pos, 1))
            pos = Builtins.search(parse_target, "/")
            Ops.set(
              @KDUMP_SAVE_TARGET,
              "share",
              Builtins.substring(parse_target, 0, pos)
            )
            Ops.set(
              @KDUMP_SAVE_TARGET,
              "dir",
              Builtins.substring(parse_target, pos)
            )
          end
        end
        debug_KDUMP_SAVE_TARGET = deep_copy(@KDUMP_SAVE_TARGET)

        if Ops.get(debug_KDUMP_SAVE_TARGET, "password", "") != ""
          Ops.set(debug_KDUMP_SAVE_TARGET, "password", "**********")
        end

        Builtins.y2milestone("--------------KDUMP_SAVE_TARGET---------------")
        Builtins.y2milestone("%1", debug_KDUMP_SAVE_TARGET)
        Builtins.y2milestone("--------------KDUMP_SAVE_TARGET---------------")

        return true
      else
        return false
      end
    end



    # Function for saving KDUMP_SAVE_TARGET
    # to standard outpu for KDUMP_SAVEDIR
    #
    # e.g. KDUMP_SAVEDIR = "ftp://[user[:pass]]@host[:port]/path

    def tostringKDUMP_SAVE_TARGET
      result = ""

      # file
      if Ops.get(@KDUMP_SAVE_TARGET, "target") == "file"
        result = "file://"

        if Ops.get(@KDUMP_SAVE_TARGET, "dir") != ""
          result = Ops.add(result, Ops.get(@KDUMP_SAVE_TARGET, "dir"))
        end 

        # ftp
      elsif Ops.get(@KDUMP_SAVE_TARGET, "target") == "ftp"
        result = "ftp://"

        if Ops.get(@KDUMP_SAVE_TARGET, "user_name") == ""
          result = Ops.add(result, Ops.get(@KDUMP_SAVE_TARGET, "server"))
          # add port if it is set...
          if Ops.get(@KDUMP_SAVE_TARGET, "port") != ""
            result = Ops.add(
              Ops.add(Ops.add(result, ":"), Ops.get(@KDUMP_SAVE_TARGET, "port")),
              Ops.get(@KDUMP_SAVE_TARGET, "dir")
            )
          else
            result = Ops.add(result, Ops.get(@KDUMP_SAVE_TARGET, "dir"))
          end
        else
          result = Ops.add(result, Ops.get(@KDUMP_SAVE_TARGET, "user_name"))

          if Ops.get(@KDUMP_SAVE_TARGET, "password") != ""
            result = Ops.add(
              Ops.add(result, ":"),
              Ops.get(@KDUMP_SAVE_TARGET, "password")
            )
          end
          result = Ops.add(
            Ops.add(result, "@"),
            Ops.get(@KDUMP_SAVE_TARGET, "server")
          )

          if Ops.get(@KDUMP_SAVE_TARGET, "port") != ""
            result = Ops.add(
              Ops.add(Ops.add(result, ":"), Ops.get(@KDUMP_SAVE_TARGET, "port")),
              Ops.get(@KDUMP_SAVE_TARGET, "dir")
            )
          else
            result = Ops.add(result, Ops.get(@KDUMP_SAVE_TARGET, "dir"))
          end
        end 

        # ssh
      elsif ["ssh", "sftp"].include?(@KDUMP_SAVE_TARGET["target"])
        result = @KDUMP_SAVE_TARGET["target"] + "://"

        if Ops.get(@KDUMP_SAVE_TARGET, "user_name") != "" &&
            Ops.get(@KDUMP_SAVE_TARGET, "password") == ""
          result = Ops.add(
            Ops.add(result, Ops.get(@KDUMP_SAVE_TARGET, "user_name")),
            "@"
          )
        elsif Ops.get(@KDUMP_SAVE_TARGET, "user_name") != "" &&
            Ops.get(@KDUMP_SAVE_TARGET, "password") != ""
          result = Ops.add(result, Ops.get(@KDUMP_SAVE_TARGET, "user_name"))
          result = Ops.add(
            Ops.add(
              Ops.add(result, ":"),
              Ops.get(@KDUMP_SAVE_TARGET, "password")
            ),
            "@"
          )
        end
        result = Ops.add(result, Ops.get(@KDUMP_SAVE_TARGET, "server"))
        # add port if it is set...
        if Ops.get(@KDUMP_SAVE_TARGET, "port") != ""
          result = Ops.add(
            Ops.add(Ops.add(result, ":"), Ops.get(@KDUMP_SAVE_TARGET, "port")),
            Ops.get(@KDUMP_SAVE_TARGET, "dir")
          )
        else
          result = Ops.add(result, Ops.get(@KDUMP_SAVE_TARGET, "dir"))
        end 


        # nfs
      elsif Ops.get(@KDUMP_SAVE_TARGET, "target") == "nfs"
        result = Ops.add(
          Ops.add("nfs://", Ops.get(@KDUMP_SAVE_TARGET, "server")),
          Ops.get(@KDUMP_SAVE_TARGET, "dir")
        ) 

        # cifs
      elsif Ops.get(@KDUMP_SAVE_TARGET, "target") == "cifs"
        result = "cifs://"

        if Builtins.findfirstof(Ops.get(@KDUMP_SAVE_TARGET, "dir", ""), "/") != 0
          Ops.set(
            @KDUMP_SAVE_TARGET,
            "dir",
            Ops.add("/", Ops.get(@KDUMP_SAVE_TARGET, "dir", ""))
          )
        end

        if Ops.get(@KDUMP_SAVE_TARGET, "user_name") == ""
          result = Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(result, Ops.get(@KDUMP_SAVE_TARGET, "server")),
                "/"
              ),
              Ops.get(@KDUMP_SAVE_TARGET, "share")
            ),
            Ops.get(@KDUMP_SAVE_TARGET, "dir")
          )
        else
          result = Ops.add(result, Ops.get(@KDUMP_SAVE_TARGET, "user_name"))

          if Ops.get(@KDUMP_SAVE_TARGET, "password") != ""
            result = Ops.add(
              Ops.add(result, ":"),
              Ops.get(@KDUMP_SAVE_TARGET, "password")
            )
          end

          result = Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(result, "@"),
                  Ops.get(@KDUMP_SAVE_TARGET, "server")
                ),
                "/"
              ),
              Ops.get(@KDUMP_SAVE_TARGET, "share")
            ),
            Ops.get(@KDUMP_SAVE_TARGET, "dir")
          )
        end
      end

      #Popup::Message(result);

      #y2milestone("-----------------KDUMP_SAVEDIR--------------------");
      #y2milestone("%1",result);
      #y2milestone("-----------------KDUMP_SAVEDIR--------------------");

      result
    end




    # Function initializes option "Save Traget for Kdump Images"
    #

    def InitTargetKdump(key)
      SetUpKDUMP_SAVE_TARGET(Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_SAVEDIR"))

      if Ops.get(@KDUMP_SAVE_TARGET, "target") == "file"
        #UI::ChangeWidget(`id ("local_filesystem"), `Value, true);
        UI.ChangeWidget(Id("TargetKdump"), :Value, "local_filesystem")
        UI.ReplaceWidget(Id("Targets"), @local_filesystem)
        UI.ChangeWidget(Id("dir"), :Value, Ops.get(@KDUMP_SAVE_TARGET, "dir"))
      elsif Ops.get(@KDUMP_SAVE_TARGET, "target") == "nfs"
        UI.ReplaceWidget(Id("Targets"), @nfs)
        #UI::ChangeWidget(`id ("nfs"), `Value, true);
        UI.ChangeWidget(Id("TargetKdump"), :Value, "nfs")
        UI.ChangeWidget(
          Id("server"),
          :Value,
          Ops.get(@KDUMP_SAVE_TARGET, "server")
        )
        UI.ChangeWidget(Id("dir"), :Value, Ops.get(@KDUMP_SAVE_TARGET, "dir"))
      elsif ["ssh", "sftp"].include?(@KDUMP_SAVE_TARGET["target"])
        UI.ReplaceWidget(Id("Targets"), @ssh)
        UI.ChangeWidget(Id("TargetKdump"), :Value, @KDUMP_SAVE_TARGET["target"])
        if Ops.get(@KDUMP_SAVE_TARGET, "port") != ""
          UI.ChangeWidget(
            Id("port"),
            :Value,
            Builtins.tointeger(Ops.get(@KDUMP_SAVE_TARGET, "port"))
          )
        end
        Builtins.foreach(["server", "user_name", "dir", "password"]) do |key2|
          UI.ChangeWidget(Id(key2), :Value, Ops.get(@KDUMP_SAVE_TARGET, key2))
        end
      elsif Ops.get(@KDUMP_SAVE_TARGET, "target") == "ftp"
        UI.ReplaceWidget(Id("Targets"), @ftp)
        #UI::ChangeWidget(`id ("ftp"), `Value, true);
        UI.ChangeWidget(Id("TargetKdump"), :Value, "ftp")
        if Ops.get(@KDUMP_SAVE_TARGET, "port") != ""
          UI.ChangeWidget(
            Id("port"),
            :Value,
            Builtins.tointeger(Ops.get(@KDUMP_SAVE_TARGET, "port"))
          )
        end
        Builtins.foreach(["server", "dir"]) do |key2|
          UI.ChangeWidget(Id(key2), :Value, Ops.get(@KDUMP_SAVE_TARGET, key2))
        end

        if Ops.get(@KDUMP_SAVE_TARGET, "user_name") == ""
          UI.ChangeWidget(Id("user_name"), :Enabled, false)
          UI.ChangeWidget(Id("password"), :Enabled, false)
          UI.ChangeWidget(Id("anonymous"), :Value, true)
        else
          UI.ChangeWidget(
            Id("user_name"),
            :Value,
            Ops.get(@KDUMP_SAVE_TARGET, "user_name")
          )
          UI.ChangeWidget(
            Id("password"),
            :Value,
            Ops.get(@KDUMP_SAVE_TARGET, "password")
          )
        end
      elsif Ops.get(@KDUMP_SAVE_TARGET, "target") == "cifs"
        UI.ReplaceWidget(Id("Targets"), @cifs)
        #UI::ChangeWidget(`id ("cifs"), `Value, true);
        UI.ChangeWidget(Id("TargetKdump"), :Value, "cifs")
        Builtins.foreach(["server", "dir", "share"]) do |key2|
          UI.ChangeWidget(Id(key2), :Value, Ops.get(@KDUMP_SAVE_TARGET, key2))
        end

        if Ops.get(@KDUMP_SAVE_TARGET, "user_name") == ""
          UI.ChangeWidget(Id("user_name"), :Enabled, false)
          UI.ChangeWidget(Id("password"), :Enabled, false)
          UI.ChangeWidget(Id("anonymous"), :Value, false)
        else
          UI.ChangeWidget(
            Id("user_name"),
            :Value,
            Ops.get(@KDUMP_SAVE_TARGET, "user_name")
          )
          UI.ChangeWidget(
            Id("password"),
            :Value,
            Ops.get(@KDUMP_SAVE_TARGET, "password")
          )
        end
      end

      nil
    end


    # Function validates options in
    # "Saving Target for Kdump Image"

    def ValidTargetKdump(key, event)
      event = deep_copy(event)
      radiobut = Builtins.tostring(UI.QueryWidget(Id("TargetKdump"), :Value))
      value = nil
      anon = true

      if radiobut == "local_filesystem"
        value = Builtins.tostring(UI.QueryWidget(Id("dir"), :Value))

        if value == nil || value == ""
          Popup.Error(_("You need to specify \"Directory for Saving Dumps\""))
          UI.SetFocus(Id("dir"))
          return false
        end
      elsif radiobut == "ftp"
        value = Builtins.tostring(UI.QueryWidget(Id("server"), :Value))

        if value == nil || value == ""
          Popup.Error(_("You need to specify \"Server Name\""))
          UI.SetFocus(Id("server"))
          return false
        end
        value = Builtins.tostring(UI.QueryWidget(Id("dir"), :Value))

        if value == nil || value == ""
          Popup.Error(_("You need to specify \"Directory on Server\""))
          UI.SetFocus(Id("dir"))
          return false
        end
        anon = Convert.to_boolean(UI.QueryWidget(Id("anonymous"), :Value))

        if !anon
          value = Builtins.tostring(UI.QueryWidget(Id("user_name"), :Value))

          if value == nil || value == ""
            Popup.Error(_("You need to specify \"User Name\""))
            UI.SetFocus(Id("user_name"))
            return false
          end
        end
      elsif ["ssh", "sftp", "nfs"].include?(radiobut)
        value = Builtins.tostring(UI.QueryWidget(Id("server"), :Value))

        if value == nil || value == ""
          Popup.Error(_("You need to specify \"Server Name\""))
          UI.SetFocus(Id("server"))
          return false
        end
        value = Builtins.tostring(UI.QueryWidget(Id("dir"), :Value))

        if value == nil || value == ""
          Popup.Error(_("You need to specify \"Directory on Server\""))
          UI.SetFocus(Id("dir"))
          return false
        end
      elsif radiobut == "cifs"
        # fix for bnc #307307 module should check if cifs tools are installed when requested
        if Mode.installation || Mode.autoinst
          Kdump.kdump_packages = Builtins.add(
            Kdump.kdump_packages,
            "cifs-mount"
          )
          Builtins.y2milestone(
            "add cifs-mount to selected packages to installation"
          )
        else
          if !Package.Installed("cifs-mount")
            Builtins.y2milestone(
              "SMB/CIFS share cannot be mounted, installing missing 'cifs-mount' package..."
            )
            # install cifs-mount package
            PackageSystem.CheckAndInstallPackages(["cifs-mount"])
          end
        end

        value = Builtins.tostring(UI.QueryWidget(Id("server"), :Value))

        if value == nil || value == ""
          Popup.Error(_("You need to specify \"Server Name\""))
          UI.SetFocus(Id("server"))
          return false
        end
        value = Builtins.tostring(UI.QueryWidget(Id("dir"), :Value))

        if value == nil || value == ""
          Popup.Error(_("You need to specify \"Directory on Server\""))
          UI.SetFocus(Id("dir"))
          return false
        end
        value = Builtins.tostring(UI.QueryWidget(Id("share"), :Value))

        if value == nil || value == ""
          Popup.Error(_("You need to specify \"Exported Share\""))
          UI.SetFocus(Id("share"))
          return false
        end
        anon = Convert.to_boolean(UI.QueryWidget(Id("anonymous"), :Value))

        if anon
          value = Builtins.tostring(UI.QueryWidget(Id("user_name"), :Value))

          if value == nil || value == ""
            Popup.Error(_("You need to specify \"User Name\""))
            UI.SetFocus(Id("user_name"))
            return false
          end #end of if ((value == nil) || (value == ""))
        end #end of if (anon)
      end #end of } else if (radiobut == "cifs")

      true
    end

    # Function handles "Saving Target for Kdump Image"
    #

    def HandleTargetKdump(key, event)
      event = deep_copy(event)
      event_name = Ops.get(event, "ID")
      #StoreTargetKdump ( key, event);
      StoreTargetKdumpHandle(@type)
      radiobut = Builtins.tostring(UI.QueryWidget(Id("TargetKdump"), :Value))
      @type = radiobut

      if event_name == "anonymous"
        value = Convert.to_boolean(UI.QueryWidget(Id("anonymous"), :Value))
        target = Builtins.tostring(UI.QueryWidget(Id("TargetKdump"), :Value))

        if value && target == "ftp" || !value && target == "cifs"
          UI.ChangeWidget(Id("user_name"), :Enabled, false)
          UI.ChangeWidget(Id("password"), :Enabled, false) 
          #KDUMP_SAVE_TARGET["user_name"]="";
          #KDUMP_SAVE_TARGET["password"]="";
        elsif value && target == "cifs" || !value && target == "ftp"
          UI.ChangeWidget(Id("user_name"), :Enabled, true)
          UI.ChangeWidget(Id("password"), :Enabled, true)
        end
      elsif radiobut == "local_filesystem"
        UI.ReplaceWidget(Id("Targets"), @local_filesystem)
        @set_network = false
        UI.ChangeWidget(Id("dir"), :Value, Ops.get(@KDUMP_SAVE_TARGET, "dir"))
        if event_name == "select_dir"
          dir = UI.AskForExistingDirectory(
            "/",
            _("Select directory for saving dump images")
          )
          UI.ChangeWidget(Id("dir"), :Value, dir)
        end
      elsif radiobut == "ftp"
        UI.ReplaceWidget(Id("Targets"), @ftp)

        if Ops.get(@KDUMP_SAVE_TARGET, "port") != ""
          UI.ChangeWidget(
            Id("port"),
            :Value,
            Builtins.tointeger(Ops.get(@KDUMP_SAVE_TARGET, "port"))
          )
        end
        Builtins.foreach(["server", "dir"]) do |key2|
          UI.ChangeWidget(Id(key2), :Value, Ops.get(@KDUMP_SAVE_TARGET, key2))
        end

        if Ops.get(@KDUMP_SAVE_TARGET, "user_name") == ""
          UI.ChangeWidget(Id("user_name"), :Enabled, false)
          UI.ChangeWidget(Id("password"), :Enabled, false)
          UI.ChangeWidget(Id("anonymous"), :Value, true)
        else
          UI.ChangeWidget(
            Id("user_name"),
            :Value,
            Ops.get(@KDUMP_SAVE_TARGET, "user_name")
          )
          UI.ChangeWidget(
            Id("password"),
            :Value,
            Ops.get(@KDUMP_SAVE_TARGET, "password")
          )
        end
      elsif ["ssh", "sftp"].include?(radiobut)
        UI.ReplaceWidget(Id("Targets"), @ssh)

        if Ops.get(@KDUMP_SAVE_TARGET, "port") != ""
          UI.ChangeWidget(
            Id("port"),
            :Value,
            Builtins.tointeger(Ops.get(@KDUMP_SAVE_TARGET, "port"))
          )
        end
        Builtins.foreach(["server", "user_name", "dir", "password"]) do |key2|
          UI.ChangeWidget(Id(key2), :Value, Ops.get(@KDUMP_SAVE_TARGET, key2))
        end
      elsif radiobut == "nfs"
        UI.ReplaceWidget(Id("Targets"), @nfs)
        UI.ChangeWidget(
          Id("server"),
          :Value,
          Ops.get(@KDUMP_SAVE_TARGET, "server")
        )
        UI.ChangeWidget(Id("dir"), :Value, Ops.get(@KDUMP_SAVE_TARGET, "dir"))
      elsif radiobut == "cifs"
        UI.ReplaceWidget(Id("Targets"), @cifs)
        Builtins.foreach(["server", "dir", "share", "user_name", "password"]) do |key2|
          UI.ChangeWidget(Id(key2), :Value, Ops.get(@KDUMP_SAVE_TARGET, key2))
        end

        if Ops.get(@KDUMP_SAVE_TARGET, "user_name") == ""
          UI.ChangeWidget(Id("user_name"), :Enabled, false)
          UI.ChangeWidget(Id("password"), :Enabled, false)
          UI.ChangeWidget(Id("anonymous"), :Value, false)
        else
          UI.ChangeWidget(
            Id("user_name"),
            :Value,
            Ops.get(@KDUMP_SAVE_TARGET, "user_name")
          )
          UI.ChangeWidget(
            Id("password"),
            :Value,
            Ops.get(@KDUMP_SAVE_TARGET, "password")
          )
        end
      end
      nil
    end
    def StoreTargetKdumpHandle(type)
      radiobut = type
      value = nil

      if radiobut == "local_filesystem"
        Ops.set(@KDUMP_SAVE_TARGET, "target", "file")
        #directory
        value = Builtins.tostring(UI.QueryWidget(Id("dir"), :Value))

        if value != nil
          Ops.set(@KDUMP_SAVE_TARGET, "dir", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "dir", "")
        end
      elsif radiobut == "ftp"
        Ops.set(@KDUMP_SAVE_TARGET, "target", "ftp")

        #server
        value = Builtins.tostring(UI.QueryWidget(Id("server"), :Value))
        if value != nil
          Ops.set(@KDUMP_SAVE_TARGET, "server", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "server", "")
        end

        #port
        if Builtins.tostring(UI.QueryWidget(Id("port"), :Value)) != "21"
          Ops.set(
            @KDUMP_SAVE_TARGET,
            "port",
            Builtins.tostring(UI.QueryWidget(Id("port"), :Value))
          )
        else
          Ops.set(@KDUMP_SAVE_TARGET, "port", "")
        end

        #directory
        value = Builtins.tostring(UI.QueryWidget(Id("dir"), :Value))
        if value != nil
          Ops.set(@KDUMP_SAVE_TARGET, "dir", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "dir", "")
        end

        #user_name vs. anonymous
        value = Builtins.tostring(UI.QueryWidget(Id("user_name"), :Value))


        if Convert.to_boolean(UI.QueryWidget(Id("anonymous"), :Value))
          Ops.set(@KDUMP_SAVE_TARGET, "user_name", "")
        elsif value != nil
          Ops.set(@KDUMP_SAVE_TARGET, "user_name", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "user_name", "")
        end

        #password
        value = Builtins.tostring(UI.QueryWidget(Id("password"), :Value))

        if value != nil && Ops.get(@KDUMP_SAVE_TARGET, "user_name") != ""
          Ops.set(@KDUMP_SAVE_TARGET, "password", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "password", "")
        end

        #directory
        if UI.QueryWidget(Id("dir"), :Value) != nil
          Ops.set(
            @KDUMP_SAVE_TARGET,
            "dir",
            Builtins.tostring(UI.QueryWidget(Id("dir"), :Value))
          )
        else
          Ops.set(@KDUMP_SAVE_TARGET, "dir", "")
        end
      elsif ["ssh", "sftp"].include?(radiobut)
        @KDUMP_SAVE_TARGET["target"] = radiobut

        #server
        value = Builtins.tostring(UI.QueryWidget(Id("server"), :Value))

        if value != nil
          Ops.set(@KDUMP_SAVE_TARGET, "server", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "server", "")
        end

        #port
        if Builtins.tostring(UI.QueryWidget(Id("port"), :Value)) != "22"
          Ops.set(
            @KDUMP_SAVE_TARGET,
            "port",
            Builtins.tostring(UI.QueryWidget(Id("port"), :Value))
          )
        else
          Ops.set(@KDUMP_SAVE_TARGET, "port", "")
        end

        #directory
        value = Builtins.tostring(UI.QueryWidget(Id("dir"), :Value))

        if value != nil
          Ops.set(@KDUMP_SAVE_TARGET, "dir", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "dir", "")
        end

        #user_name
        value = Builtins.tostring(UI.QueryWidget(Id("user_name"), :Value))

        if value != nil
          Ops.set(@KDUMP_SAVE_TARGET, "user_name", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "user_name", "")
        end

        #password
        value = Builtins.tostring(UI.QueryWidget(Id("password"), :Value))

        if value != nil && Ops.get(@KDUMP_SAVE_TARGET, "user_name") != ""
          Ops.set(@KDUMP_SAVE_TARGET, "password", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "password", "")
        end
      elsif radiobut == "nfs"
        Ops.set(@KDUMP_SAVE_TARGET, "target", "nfs")

        #server
        value = Builtins.tostring(UI.QueryWidget(Id("server"), :Value))

        if value != nil
          Ops.set(@KDUMP_SAVE_TARGET, "server", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "server", "")
        end

        #directory
        value = Builtins.tostring(UI.QueryWidget(Id("dir"), :Value))

        if value != nil
          Ops.set(@KDUMP_SAVE_TARGET, "dir", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "dir", "")
        end
      elsif radiobut == "cifs"
        Ops.set(@KDUMP_SAVE_TARGET, "target", "cifs")

        #server
        value = Builtins.tostring(UI.QueryWidget(Id("server"), :Value))

        if value != nil
          Ops.set(@KDUMP_SAVE_TARGET, "server", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "server", "")
        end

        #share
        value = Builtins.tostring(UI.QueryWidget(Id("share"), :Value))

        if value != nil
          Ops.set(@KDUMP_SAVE_TARGET, "share", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "share", "")
        end

        #directory
        value = Builtins.tostring(UI.QueryWidget(Id("dir"), :Value))

        if value != nil
          Ops.set(@KDUMP_SAVE_TARGET, "dir", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "dir", "")
        end

        #user_name vs. anonymous
        value = Builtins.tostring(UI.QueryWidget(Id("user_name"), :Value))

        if !Convert.to_boolean(UI.QueryWidget(Id("anonymous"), :Value))
          Ops.set(@KDUMP_SAVE_TARGET, "user_name", "")
        elsif value != nil
          Ops.set(@KDUMP_SAVE_TARGET, "user_name", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "user_name", "")
        end

        #password
        value = Builtins.tostring(UI.QueryWidget(Id("password"), :Value))

        if value != nil && Ops.get(@KDUMP_SAVE_TARGET, "user_name") != ""
          Ops.set(@KDUMP_SAVE_TARGET, "password", value)
        else
          Ops.set(@KDUMP_SAVE_TARGET, "password", "")
        end
      end
      Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_SAVEDIR", tostringKDUMP_SAVE_TARGET)

      nil
    end

    # Function stores option
    # "Saving Target for kdump Image"

    def StoreTargetKdump(key, event)
      event = deep_copy(event)
      radiobut = Builtins.tostring(UI.QueryWidget(Id("TargetKdump"), :Value))
      @type = Builtins.tostring(UI.QueryWidget(Id("TargetKdump"), :Value))

      nil
    end



    # Function initializes option "Kdump Command Line"
    #

    def InitKdumpCommandLine(key)
      value = ""
      value = Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_COMMANDLINE")
      UI.ChangeWidget(Id("KdumpCommandLine"), :Value, value == nil ? "" : value)

      nil
    end

    # Function stores option "Kdump Command Line"
    #
    def StoreKdumpCommandLine(key, event)
      event = deep_copy(event)
      Ops.set(
        Kdump.KDUMP_SETTINGS,
        "KDUMP_COMMANDLINE",
        Builtins.tostring(UI.QueryWidget(Id("KdumpCommandLine"), :Value))
      )

      nil
    end


    # Function initializes option "Kdump Command Line Append"
    #

    def InitKdumpCommandLineAppend(key)
      value = ""
      value = Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_COMMANDLINE_APPEND")
      UI.ChangeWidget(
        Id("KdumpCommandLineAppend"),
        :Value,
        value == nil ? "" : value
      )

      nil
    end

    # Function stores option "Kdump Command Line Append"
    #
    def StoreKdumpCommandLineAppend(key, event)
      event = deep_copy(event)
      Ops.set(
        Kdump.KDUMP_SETTINGS,
        "KDUMP_COMMANDLINE_APPEND",
        Builtins.tostring(UI.QueryWidget(Id("KdumpCommandLineAppend"), :Value))
      )

      nil
    end


    # Function initializes option "Number of Old Dumps"
    def InitNumberDumps(key)
      UI.ChangeWidget(
        Id("NumberDumps"),
        :Value,
        Builtins.tointeger(
          Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_KEEP_OLD_DUMPS")
        )
      )

      nil
    end

    # Function stores option "Number of Old Dumps"
    def StoreNumberDumps(key, event)
      event = deep_copy(event)
      Ops.set(
        Kdump.KDUMP_SETTINGS,
        "KDUMP_KEEP_OLD_DUMPS",
        Builtins.tostring(UI.QueryWidget(Id("NumberDumps"), :Value))
      )

      nil
    end

    # Function initializes option
    # "Enable Immediate Reboot After Saving the Core"

    def InitEnableReboot(key)
      UI.ChangeWidget(
        Id("EnableReboot"),
        :Value,
        Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_IMMEDIATE_REBOOT") == "yes" ? true : false
      )

      nil
    end

    # Function stores option
    # "Enable Immediate Reboot After Saving the Core"

    def StoreEnableReboot(key, event)
      event = deep_copy(event)
      Ops.set(
        Kdump.KDUMP_SETTINGS,
        "KDUMP_IMMEDIATE_REBOOT",
        Convert.to_boolean(UI.QueryWidget(Id("EnableReboot"), :Value)) ? "yes" : "no"
      )

      nil
    end

    # Function initializes option
    # "Dump Level" - visualization in UI

    def SetDumpLevel(bit_number)
      counter = -1
      Builtins.foreach(
        ["free_page", "user_data", "cache_private", "cache_page", "zero_page"]
      ) do |key|
        counter = Ops.add(counter, 1)
        one_bit = Builtins.substring(bit_number, counter, 1)
        UI.ChangeWidget(Id(key), :Value, one_bit == "1" ? false : true)
      end

      nil
    end

    # Function initializes option
    # "Dump Level"


    def InitDumpLevel(key)
      value = Builtins.tointeger(
        Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_DUMPLEVEL")
      )
      ret = ""
      Builtins.foreach(@bit_weight_row) do |try_i|
        if Ops.greater_than(Ops.divide(value, try_i), 0)
          value = Ops.modulo(value, try_i)
          ret = Ops.add(ret, "1")
        else
          ret = Ops.add(ret, "0")
        end
      end

      #Popup::Message(ret);
      SetDumpLevel(ret)

      nil
    end

    # Function store option
    # "Dump Level" - info from UI checkboxes
    # @result string binary code e.g. 11000

    def GetDumpLevel
      ret = ""
      Builtins.foreach(
        ["free_page", "user_data", "cache_private", "cache_page", "zero_page"]
      ) do |key|
        if Convert.to_boolean(UI.QueryWidget(Id(key), :Value))
          ret = Ops.add(ret, "0")
        else
          ret = Ops.add(ret, "1")
        end
      end
      #Popup::Message(ret);
      ret
    end


    # Function validates options in
    # "Dump Level"
    # install makedumpfile if KDUMP_DUMPLEVEL > 0

    def ValidDumpLevel(key, event)
      event = deep_copy(event)
      result = true
      value = GetDumpLevel()
      counter = -1
      dumplevel = 0

      while Ops.less_than(counter, 5)
        counter = Ops.add(counter, 1)
        one_bit = Builtins.substring(value, counter, 1)
        if one_bit == "1"
          dumplevel = Ops.add(dumplevel, Ops.get(@bit_weight_row, counter, 0))
        end
      end

      if Ops.greater_than(dumplevel, 0) || dumplevel == nil
        if Mode.installation || Mode.autoinst
          Kdump.kdump_packages = Builtins.add(
            Kdump.kdump_packages,
            "makedumpfile"
          )
          Builtins.y2milestone(
            "add makedumpfile to selected packages to installation"
          )
        else
          if Package.Installed("makedumpfile")
            return true
          else
            package_list = []
            package_list = Builtins.add(package_list, "makedumpfile")

            if !PackageSystem.CheckAndInstallPackages(package_list)
              result = false

              if !Mode.commandline
                Popup.Error(Message.CannotContinueWithoutPackagesInstalled)
              else
                CommandLine.Error(
                  Message.CannotContinueWithoutPackagesInstalled
                )
              end
              Builtins.y2error(
                "[kdump] (ValidDumpLevel) Installation of package list %1 failed or aborted",
                package_list
              )
            else
              result = true
            end
          end #end of else for if (Package::Installed("makedumpfile"))
        end
      end #end of if ((dumplevel >0 ) || (dumplevel == nil))
      result
    end


    # Function stores option
    # "Dump Level"
    def StoreDumpLevel(key, event)
      event = deep_copy(event)
      value = GetDumpLevel()
      counter = -1
      int_value = 0
      while Ops.less_than(counter, 5)
        counter = Ops.add(counter, 1)
        one_bit = Builtins.substring(value, counter, 1)
        if one_bit == "1"
          int_value = Ops.add(int_value, Ops.get(@bit_weight_row, counter, 0))
        end
      end

      ret = Builtins.tostring(int_value)
      Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_DUMPLEVEL", ret) 
      #Popup::Message(ret);

      nil
    end


    #  Hadle function for option
    # "Dump Level"

    def HandleDumpLevel(key, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      if ret == "cache_private"
        value_cache_private = Convert.to_boolean(
          UI.QueryWidget(Id("cache_private"), :Value)
        )
        value_cache_page = Convert.to_boolean(
          UI.QueryWidget(Id("cache_page"), :Value)
        )
        if value_cache_private && !value_cache_page
          UI.ChangeWidget(Id("cache_page"), :Value, true)
        end
      end

      if ret == "cache_page"
        value_cache_private = Convert.to_boolean(
          UI.QueryWidget(Id("cache_private"), :Value)
        )
        value_cache_page = Convert.to_boolean(
          UI.QueryWidget(Id("cache_page"), :Value)
        )
        if value_cache_private && !value_cache_page
          UI.ChangeWidget(Id("cache_private"), :Value, false)
        end
      end
      nil
    end

    # Function initializes option
    # "KdumpMemory"


    def InitKdumpMemory(key)
      if Ops.greater_than(Kdump.total_memory, 0)
        UI.ChangeWidget(
          Id("total_memory"),
          :Value,
          Builtins.tostring(Kdump.total_memory)
        )
        UI.ChangeWidget(
          Id("allocated_memory"),
          :Value,
          Builtins.tointeger(Kdump.allocated_memory)
        )
        UI.ChangeWidget(
          Id("usable_memory"),
          :Value,
          Builtins.tostring(
            Ops.subtract(
              Kdump.total_memory,
              Convert.to_integer(UI.QueryWidget(Id("allocated_memory"), :Value))
            )
          )
        )
      else
        UI.ChangeWidget(Id("total_memory"), :Value, "0")
        UI.ChangeWidget(Id("usable_memory"), :Value, "0")
        UI.ChangeWidget(Id("allocated_memory"), :Enabled, false)
      end

      nil
    end

    #  Hadle function for option
    # "KdumpMemory"

    def HandleKdumpMemory(key, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      if ret == "allocated_memory"
        value = Convert.to_integer(UI.QueryWidget(Id("allocated_memory"), :Value))
        if Ops.greater_than(value, Kdump.total_memory)
          UI.ChangeWidget(Id("allocated_memory"), :Value, Kdump.total_memory)
          UI.ChangeWidget(Id("usable_memory"), :Value, "0")
        else
          UI.ChangeWidget(
            Id("usable_memory"),
            :Value,
            Builtins.tostring(
              Ops.subtract(
                Kdump.total_memory,
                Convert.to_integer(UI.QueryWidget(Id("allocated_memory"), :Value))
              )
            )
          )
        end
      end

      nil
    end


    # Function validates if crashkernel option includes
    # several ranges and ask user about rewritting
    #
    #"KdumpMemory"

    def ValidKdumpMemory(key, event)
      event = deep_copy(event)
      if Kdump.crashkernel_list_ranges && Mode.normal
        Kdump.crashkernel_list_ranges = !Popup.YesNo(
          _("Kernel option includes several ranges. Rewrite it?")
        )
      end

      true
    end
    #  Store function for option
    # "KdumpMemory"

    def StoreKdumpMemory(key, event)
      event = deep_copy(event)
      Kdump.allocated_memory = Builtins.tostring(
        UI.QueryWidget(Id("allocated_memory"), :Value)
      )

      nil
    end

    # Initializes FADump settings in UI
    def InitFADump(key)
      if Kdump.fadump_supported? && UI.WidgetExists(Id("FADump"))
        UI.ReplaceWidget(
          Id("FADump"),
          VBox(
            CheckBox(
              Id("use_fadump"),
              Opt(:notify),
              # T: Checkbox label
              _("Use &Firmware-Assisted Dump"),
              Kdump.using_fadump?
            ),
            VSpacing(1)
          )
        )
      end
    end

    def HandleFADump(key, event)
      return if event["ID"] != "use_fadump"

      # If cannot adjust the fadump usage
      if ! Kdump.use_fadump(UI.QueryWidget(Id("use_fadump"), :Value))
        UI.ChangeWidget(Id("use_fadump"), :Value, false)
      end

      nil
    end

    # Function initializes option
    # "Custom kdump Kernel"


    def InitInitrdKernel(key)
      UI.ChangeWidget(
        Id("InitrdKernel"),
        :Value,
        Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_KERNELVER")
      )

      nil
    end



    # Function stores option
    # "Custom kdump Kernel"
    def StoreInitrdKernel(key, event)
      event = deep_copy(event)
      Ops.set(
        Kdump.KDUMP_SETTINGS,
        "KDUMP_KERNELVER",
        Builtins.tostring(UI.QueryWidget(Id("InitrdKernel"), :Value))
      )

      nil
    end


    # Function initializes option
    # "Dump Format"

    def InitDumpFormat(key)
      if Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_DUMPFORMAT") == "ELF"
        UI.ChangeWidget(Id("DumpFormat"), :Value, "elf_format")
      elsif Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_DUMPFORMAT") == "compressed"
        UI.ChangeWidget(Id("DumpFormat"), :Value, "compressed_format")
      elsif Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_DUMPFORMAT") == "lzo"
        UI.ChangeWidget(Id("DumpFormat"), :Value, "lzo_format")
      else
        UI.ChangeWidget(Id("DumpFormat"), :Value, "none_format")
      end

      nil
    end


    # Function validates options in
    # "Dump Format"
    # install makedumpfile if KDUMP_DUMPFORMAT == "compressed"

    def ValidDumpFormat(key, event)
      event = deep_copy(event)
      result = true
      value = Builtins.tostring(UI.QueryWidget(Id("DumpFormat"), :Value))

      if value != "elf_format" || value == nil
        if Mode.installation || Mode.autoinst
          Kdump.kdump_packages = Builtins.add(
            Kdump.kdump_packages,
            "makedumpfile"
          )
          Builtins.y2milestone(
            "add makedumpfile to selected packages to installation"
          )
        else
          if Package.Installed("makedumpfile")
            return true
          else
            package_list = []
            package_list = Builtins.add(package_list, "makedumpfile")

            if !PackageSystem.CheckAndInstallPackages(package_list)
              result = false

              if !Mode.commandline
                Popup.Error(Message.CannotContinueWithoutPackagesInstalled)
              else
                CommandLine.Error(
                  Message.CannotContinueWithoutPackagesInstalled
                )
              end
              Builtins.y2error(
                "[kdump] (ValidDumpFormat) Installation of package list %1 failed or aborted",
                package_list
              )
            else
              result = true
            end
          end #end of else for if (Package::Installed("makedumpfile"))
        end
      end #end of if ((value != "elf_format") || (value == nil))
      result
    end

    # Function stores option
    # "Dump Format"

    def StoreDumpFormat(key, event)
      event = deep_copy(event)
      value = Builtins.tostring(UI.QueryWidget(Id("DumpFormat"), :Value))
      if value == "elf_format"
        Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_DUMPFORMAT", "ELF")
      elsif value == "compressed_format"
        Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_DUMPFORMAT", "compressed")
      elsif value == "lzo_format"
        Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_DUMPFORMAT", "lzo")
      else
        Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_DUMPFORMAT", "none")
      end

      nil
    end

    # Function initializes option
    # "Enable Delete Old Dump Images"

    def InitEnableDeleteImages(key)
      UI.ChangeWidget(Id("EnableDeleteImages"), :Notify, true)
      if Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_KEEP_OLD_DUMPS") != "0"
        UI.ChangeWidget(Id("NumberDumps"), :Enabled, true)
        UI.ChangeWidget(Id("EnableDeleteImages"), :Value, true)
      else
        UI.ChangeWidget(Id("EnableDeleteImages"), :Value, false)
        UI.ChangeWidget(Id("NumberDumps"), :Enabled, false)
      end

      nil
    end

    #  Hadle function for option
    # "Enable Delete Old Dump Images"

    def HandleEnableDeleteImages(key, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      if ret == "EnableDeleteImages"
        value = Convert.to_boolean(
          UI.QueryWidget(Id("EnableDeleteImages"), :Value)
        )
        if !value
          UI.ChangeWidget(Id("NumberDumps"), :Value, Builtins.tointeger("0"))
          UI.ChangeWidget(Id("NumberDumps"), :Enabled, false)
        else
          UI.ChangeWidget(
            Id("NumberDumps"),
            :Value,
            Builtins.tointeger(
              Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_KEEP_OLD_DUMPS")
            )
          )
          UI.ChangeWidget(Id("NumberDumps"), :Enabled, true)
        end
      end

      nil
    end


    # Function stores option
    # "Enable Delete Old Dump Images"

    def StoreEnableDeleteImages(key, event)
      event = deep_copy(event)
      value = Convert.to_boolean(
        UI.QueryWidget(Id("EnableDeleteImages"), :Value)
      )
      Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_KEEP_OLD_DUMPS", "0") if !value

      nil
    end


    # Function initializes option
    # "Enable Copy Kernel into the Dump Directory"

    def InitEnableCopyKernel(key)
      if Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_COPY_KERNEL", "no") == "yes"
        UI.ChangeWidget(Id("EnableCopyKernel"), :Value, true)
      else
        UI.ChangeWidget(Id("EnableCopyKernel"), :Value, false)
      end

      nil
    end



    # Function stores option
    # "Enable Copy Kernel into the Dump Directory"

    def StoreEnableCopyKernel(key, event)
      event = deep_copy(event)
      value = Convert.to_boolean(UI.QueryWidget(Id("EnableCopyKernel"), :Value))
      if !value
        Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_COPY_KERNEL", "no")
      else
        Ops.set(Kdump.KDUMP_SETTINGS, "KDUMP_COPY_KERNEL", "yes")
      end

      nil
    end


    # Function initializes option
    # "SMTP Server"
    def InitSMTPServer(key)
      UI.ChangeWidget(
        Id("SMTPServer"),
        :Value,
        Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_SMTP_SERVER", "")
      )

      nil
    end

    # Function stores option
    # "SMTP Server"
    def StoreSMTPServer(key, event)
      event = deep_copy(event)
      Ops.set(
        Kdump.KDUMP_SETTINGS,
        "KDUMP_SMTP_SERVER",
        Builtins.tostring(UI.QueryWidget(Id("SMTPServer"), :Value))
      )

      nil
    end

    # Function initializes option
    # "User Name" (SMTP Settings)
    def InitSMTPUser(key)
      UI.ChangeWidget(
        Id("SMTPUser"),
        :Value,
        Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_SMTP_USER", "")
      )

      nil
    end

    # Function stores option
    # "User Name" (SMTP Settings)
    def StoreSMTPUser(key, event)
      event = deep_copy(event)
      Ops.set(
        Kdump.KDUMP_SETTINGS,
        "KDUMP_SMTP_USER",
        Builtins.tostring(UI.QueryWidget(Id("SMTPUser"), :Value))
      )

      nil
    end

    # Function initializes option
    # "Password" (SMTP Settings)
    def InitSMTPPassword(key)
      UI.ChangeWidget(
        Id("SMTPPassword"),
        :Value,
        Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_SMTP_PASSWORD", "")
      )

      nil
    end

    # Function stores option
    # "Password" (SMTP Settings)
    def StoreSMTPPassword(key, event)
      event = deep_copy(event)
      Ops.set(
        Kdump.KDUMP_SETTINGS,
        "KDUMP_SMTP_PASSWORD",
        Builtins.tostring(UI.QueryWidget(Id("SMTPPassword"), :Value))
      )

      nil
    end

    # Function initializes option
    # "Notification To"
    def InitNotificationTo(key)
      UI.ChangeWidget(
        Id("NotificationTo"),
        :Value,
        Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_NOTIFICATION_TO", "")
      )

      nil
    end

    # Function stores option
    # "Notification To"
    def StoreNotificationTo(key, event)
      event = deep_copy(event)
      Ops.set(
        Kdump.KDUMP_SETTINGS,
        "KDUMP_NOTIFICATION_TO",
        Builtins.tostring(UI.QueryWidget(Id("NotificationTo"), :Value))
      )

      nil
    end

    # Function initializes option
    # "Notification CC"
    def InitNotificationCC(key)
      UI.ChangeWidget(
        Id("NotificationCC"),
        :Value,
        Ops.get(Kdump.KDUMP_SETTINGS, "KDUMP_NOTIFICATION_CC", "")
      )

      nil
    end

    # Function stores option
    # "Notification CC"
    def StoreNotificationCC(key, event)
      event = deep_copy(event)
      Ops.set(
        Kdump.KDUMP_SETTINGS,
        "KDUMP_NOTIFICATION_CC",
        Builtins.tostring(UI.QueryWidget(Id("NotificationCC"), :Value))
      )

      nil
    end


    # Function validates options in
    # "Dump Format"
    # install makedumpfile if KDUMP_DUMPFORMAT == "compressed"

    def ValidEmail(key, event)
      event = deep_copy(event)
      Popup.Message(key)
      true
    end
  end
end
