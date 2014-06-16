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

# File:	modules/Kdump.ycp
# Package:	Configuration of kdump
# Summary:	Kdump settings, input and output functions
# Authors:	Jozef Uhliarik <juhliarik@suse.com>
#
# $Id: Kdump.ycp 27914 2006-02-13 14:32:08Z locilka $
#
# Representation of the configuration of kdump.
# Input and output routines.
require "yast"

module Yast
  class KdumpClass < Module
    include Yast::Logger

    FADUMP_KEY = "KDUMP_FADUMP"
    KDUMP_SERVICE_NAME = "kdump"

    def main
      textdomain "kdump"

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Summary"
      Yast.import "Message"
      Yast.import "BootCommon"
      #import "Storage";
      Yast.import "Map"
      Yast.import "Bootloader"
      Yast.import "Service"
      Yast.import "Popup"
      Yast.import "Arch"
      Yast.import "Mode"
      Yast.import "ProductControl"
      Yast.import "ProductFeatures"
      Yast.import "PackagesProposal"
      Yast.import "FileUtils"
      Yast.import "Directory"

      # Data was modified?
      @modified = false

      # kdump config file

      @kdump_file = "/etc/sysconfig/kdump"



      @proposal_valid = false

      # List of available partiotions
      # with known partition
      #
      # list <string>
      @available_partitions = []

      # true if propose was called
      @propose_called = false

      # List of available partiotions
      # without filesystem or with uknown
      #
      # list <string>
      @uknown_fs_partitions = []

      # Total available memory [MB]
      #
      #
      # integer
      @total_memory = 0

      # Boolean option indicates that "crashkernel" includes
      #  several ranges
      #
      # boolean true if there are several ranges (>1)
      @crashkernel_list_ranges = false


      #  list of packages for installation
      @kdump_packages = []

      # Number of cpus
      #
      # integer
      @number_of_cpus = 1

      # kernel version (uname -r)
      #
      # string
      @kernel_version = ""


      # Position actual boot section in BootCommon::sections list
      # it is relevant only if XEN boot section is used
      #
      # integer
      @section_pos = -1


      # Boolean option indicates kernel parameter
      # "crashkernel"
      #
      # boolean true if kernel parameter is set
      @crashkernel_param = false

      # String option indicates value of kernel parameter
      # "crashkernel"
      #
      # string value of kernel parameter
      @crashkernel_param_value = ""

      # Boolean option indicates add kernel param
      # "crashkernel"
      #
      # boolean true if kernel parameter will be add
      @add_crashkernel_param = false


      # String option for alocate of memory for boot param
      # "crashkernel"
      #
      # string value number of alocate memory
      @allocated_memory = "0"

      # Boolean option indicates that Import()
      # was called and data was proposed
      #
      # boolean true if import was called with data

      @import_called = false


      # Write only, used during autoinstallation.
      # Don't run services and SuSEconfig, it's all done at one place.
      @write_only = false

      # Abort function
      # return boolean return true if abort
      @AbortFunction = nil

      # map of deafult values for options in UI
      #
      # global map <string, string >

      @DEFAULT_CONFIG = {
        "KDUMP_KERNELVER"          => "",
        "KDUMP_COMMANDLINE"        => "",
        "KDUMP_COMMANDLINE_APPEND" => "",
        "KEXEC_OPTIONS"            => "",
        "KDUMP_IMMEDIATE_REBOOT"   => "yes",
        "KDUMP_COPY_KERNEL"        => "yes",
        "KDUMP_TRANSFER"           => "",
        "KDUMP_SAVEDIR"            => "file:///var/crash",
        "KDUMP_KEEP_OLD_DUMPS"     => "5",
        "KDUMP_FREE_DISK_SIZE"     => "64",
        "KDUMP_VERBOSE"            => "3",
        "KDUMP_DUMPLEVEL"          => "31",
        "KDUMP_DUMPFORMAT"         => "lzo",
        "KDUMP_SMTP_SERVER"        => "",
        "KDUMP_SMTP_USER"          => "",
        "KDUMP_SMTP_PASSWORD"      => "",
        "KDUMP_NOTIFICATION_TO"    => "",
        "KDUMP_NOTIFICATION_CC"    => ""
      }

      # map <string, string > of kdump settings
      #
      @KDUMP_SETTINGS = {}

      # initial kdump settings replaced in Read function
      @initial_kdump_settings = deep_copy(@KDUMP_SETTINGS)
    end

    # Abort function
    # @return [Boolean] return true if abort
    def Abort
      return @AbortFunction.call == true if @AbortFunction != nil
      false
    end

    # Data was modified?
    # @return true if modified
    def GetModified
      Builtins.y2debug("modified=%1", @modified)
      @modified
    end


    # Set data was modified
    def SetModified
      @modified = true
      Builtins.y2debug("modified=%1", @modified)

      nil
    end

    # Function set permission for file.
    #
    # @return	[Boolean] true on success
    # @param	string file name
    # @param [String] permissions
    #
    # @example
    #	FileUtils::Chmod ("/etc/sysconfig/kdump", "600") -> true
    #	FileUtils::Chmod ("/tmp/doesnt_exist", "644") -> false
    def Chmod(target, permissions)
      if !FileUtils.Exists(target)
        Builtins.y2error("Target %1 doesn't exist", target)
        return false
      end

      if !FileUtils.Exists("/bin/chmod")
        Builtins.y2error("tool: /bin/chmod not found")
        return false
      end

      cmd = Builtins.sformat("/bin/chmod %1 %2", permissions, target)
      cmd_out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))

      if Ops.get_integer(cmd_out, "exit", -1) != 0
        Builtins.y2error("Command >%1< returned %2", cmd, cmd_out)
        return false
      end
      Builtins.y2milestone("Command: %1 finish successful.", cmd)
      true
    end

    # Function check if KDUMP_SAVEDIR or
    # KDUMP_SMTP_PASSWORD include password
    #
    # @return [Boolean] true if inlude password

    def checkPassword
      return true if Ops.get(@KDUMP_SETTINGS, "KDUMP_SMTP_PASSWORD", "") != ""

      if Builtins.search(Ops.get(@KDUMP_SETTINGS, "KDUMP_SAVEDIR", ""), "file") != nil ||
          Builtins.search(Ops.get(@KDUMP_SETTINGS, "KDUMP_SAVEDIR", ""), "nfs") != nil ||
          Ops.get(@KDUMP_SETTINGS, "KDUMP_SAVEDIR", "") == ""
        return false
      end

      if Builtins.search(Ops.get(@KDUMP_SETTINGS, "KDUMP_SAVEDIR", ""), "@") == nil
        return false
      end

      temp = Builtins.splitstring(
        Ops.get(@KDUMP_SETTINGS, "KDUMP_SAVEDIR", ""),
        "@"
      )
      temp_1 = Ops.get(temp, 0, "")
      position = Builtins.findlastof(temp_1, ":")
      return false if position == nil

      # if there is 2 times ":" -> it means that password is defined
      # for example cifs://login:password@server....
      if Ops.greater_than(position, 6)
        return true
      else
        return false
      end
    end


    # get allocated memory from value of crashkernel option
    # there can be several ranges -> take the first range
    #  @param string 64M@16M or 128M-:64M@16M [(reserved_memory*2)-:reserved_memory]
    #  @return [String] value of allocated memory (64M)

    def getAllocatedMemory(crash_value)
      result = ""
      allocated = ""
      range = ""
      if Builtins.search(crash_value, ",") != nil
        ranges = Builtins.splitstring(crash_value, ",")
        @crashkernel_list_ranges = true
        range = Ops.get(ranges, 0, "")
      else
        range = crash_value
      end
      Builtins.y2milestone("The 1st range from crashkernel is %1", range)
      position = Builtins.search(range, ":")

      if position != nil
        allocated = Builtins.substring(range, Ops.add(position, 1))
      else
        allocated = range
      end

      result = Builtins.substring(allocated, 0, Builtins.search(allocated, "M"))

      Builtins.y2milestone("Allocated memory is %1", result)
      result
    end

    # Build crashkernel value from allocated memory
    #
    #  @return [String] value of crashkernel

    def BuildCrashkernelValue
      # If user didn't modify or select return old value.
      return @crashkernel_param_value if @crashkernel_list_ranges

      crash_value = @allocated_memory + "M"
      reserved_memory = (@allocated_memory.to_i * 2).to_s
      crash_value = reserved_memory + "M-:" + crash_value

      log.info "built crashkernel value is #{crash_value}"

      crash_value
    end

    # Read current kdump configuration
    #
    # read kernel parameter "crashkernel"
    #  @return [Boolean] successfull

    def ReadKdumpKernelParam
      result = Bootloader.kernel_param(:common, "crashkernel")
      result = Bootloader.kernel_param(:xen_guest, "crashkernel") if result == :missing

      #Popup::Message(result);
      if result == :missing
        @crashkernel_param = false
        @add_crashkernel_param = false
      else
        @crashkernel_param = true
        @add_crashkernel_param = true
      end

      @crashkernel_param_value = result
      if result != :missing
        @allocated_memory = getAllocatedMemory(@crashkernel_param_value)
      end

      true
    end

    TEMPORARY_CONFIG_FILE = "/var/lib/YaST2/kdump.sysconfig"
    TEMPORARY_CONFIG_PATH = Path.new(".temporary.sysconfig.kdump")

    def write_temporary_config_file
      SCR.RegisterAgent(TEMPORARY_CONFIG_PATH,
                        term(:ag_ini,
                             term(:SysConfigFile, TEMPORARY_CONFIG_FILE)
                             )
                        )
      WriteKdumpSettingsTo(TEMPORARY_CONFIG_PATH, TEMPORARY_CONFIG_FILE)
      SCR.UnregisterAgent(TEMPORARY_CONFIG_PATH)
    end

    PROPOSE_ALLOCATED_MEMORY_MB_COMMAND = "kdumptool --configfile #{TEMPORARY_CONFIG_FILE} calibrate"
    # if the command fails
    PROPOSE_ALLOCATED_MEMORY_MB_FALLBACK = "128"

    # Propose reserved/allocated memory
    # Store the result as a string! to @allocated_memory
    # @return [Boolean] true, always successful
    def ProposeAllocatedMemory
      # only propose once
      return true if @allocated_memory != "0"

      write_temporary_config_file
      out = SCR.Execute(path(".target.bash_output"), PROPOSE_ALLOCATED_MEMORY_MB_COMMAND)
      @allocated_memory = out["stdout"].chomp
      if out["exit"] != 0 or @allocated_memory.empty?
        # stderr has been already logged
        Builtins.y2error("failed to propose allocated memory")
        @allocated_memory = PROPOSE_ALLOCATED_MEMORY_MB_FALLBACK
      end
      Builtins.y2milestone(
        "[kdump] allocated memory if not set in \"crashkernel\" param: %1",
        @allocated_memory
      )
      true
    end

    # Read available memory
    #
    #
    #  @return [Boolean] successfull

    def ReadAvailableMemory
      output = Convert.convert(
        SCR.Read(path(".probe.memory")),
        :from => "any",
        :to   => "list <map>"
      )
      Builtins.y2milestone(
        "[kdump] (ReadAvailableMemory) SCR::Read(.probe.memory): %1",
        output
      )

      resor = {}
      temp = Builtins.maplist(output) { |mem| Ops.get(mem, "resource") }
      #y2milestone("[kdump] (ReadAvailableMemory) temp: %1", temp);
      resor = Builtins.tomap(Ops.get(temp, 0))

      output = Convert.convert(
        Ops.get(resor, "phys_mem"),
        :from => "any",
        :to   => "list <map>"
      )
      temp = Builtins.maplist(output) { |mem| Ops.get(mem, "range") }
      #list <any> range = maplist(map resor["phys_mem"]:nil);

      #resor = (map)range;
      @total_memory = Ops.divide(Builtins.tointeger(Ops.get(temp, 0)), 1048576)
      Builtins.y2milestone(
        "[kdump] (ReadAvailableMemory) total phys. memory [MB]: %1",
        Builtins.tostring(@total_memory)
      )
      true
    end


    def log_settings_censoring_passwords(message)
      debug_KDUMP_SETTINGS = deep_copy(@KDUMP_SETTINGS)
      debug_KDUMP_SETTINGS["KDUMP_SAVEDIR"]       = "********"
      debug_KDUMP_SETTINGS["KDUMP_SMTP_PASSWORD"] = "********"

      log.info "-------------KDUMP_SETTINGS-------------------"
      log.info "#{message}; here with censored passwords: #{debug_KDUMP_SETTINGS}"
      log.info "---------------------------------------------"
    end

    # Read current kdump configuration
    #
    #  @return [Boolean] successful
    def ReadKdumpSettings
      @KDUMP_SETTINGS = deep_copy(@DEFAULT_CONFIG)
      SCR.Dir(path(".sysconfig.kdump")).each do |key|
        val = Convert.to_string(
          SCR.Read(path(".sysconfig.kdump") + key)
        )
        @KDUMP_SETTINGS[key] = val
      end

      log_settings_censoring_passwords("kdump configuration has been read")

      @initial_kdump_settings = deep_copy(@KDUMP_SETTINGS)

      true
    end

    # Updates initrd and reports whether it was successful.
    # Failed update is reported using Report library.
    #
    # @return [Boolean] whether successful
    def update_initrd
      # See FATE#315780
      # See https://www.suse.com/support/kb/doc.php?id=7012786
      # FIXME what about dracut?
      update_command = (using_fadump? ? "mkdumprd -f" : "mkinitrd")
      update_logfile = File.join(Directory.vardir, "y2logmkinitrd")

      run_command = update_command + " >> #{update_logfile} 2>&1"
      y2milestone("Running command: #{run_command}")
      ret = SCR.Execute(path(".target.bash"), run_command)

      if ret != 0
        y2error("Error updating initrd, see #{update_logfile} or call {update_command} manually")
        Report.Error(_(
          "Error updating initrd while calling '%{cmd}'.\n" +
          "See %{log} for details."
        ) % { :cmd => update_command, :log => update_logfile })
        return false
      end

      true
    end

    # Writes a file in the /etc/sysconfig/kdump format
    def WriteKdumpSettingsTo(scr_path, file_name)
      log_settings_censoring_passwords("kdump configuration for writing")

      @KDUMP_SETTINGS.each do |option_key, option_val|
        SCR.Write(scr_path + option_key, option_val)
      end
      SCR.Write(scr_path, nil)

      if checkPassword
        Chmod(file_name, "600")
      else
        Chmod(file_name, "644")
      end
    end

    # Write current kdump configuration
    #
    #  @return [Boolean] successful
    def WriteKdumpSettings
      WriteKdumpSettingsTo(path(".sysconfig.kdump"), @kdump_file)

      if using_fadump_changed? && ! update_initrd
        return false
      end

      true
    end

    # Write kdump boot argument crashkernel
    # set kernel-kdump start at boot
    #
    #  @return [Boolean] successfull
    def WriteKdumpBootParameter
      result = true
      old_progress = false

      if @add_crashkernel_param
        crash_value = ""
        crash_value = BuildCrashkernelValue() if !Mode.autoinst

        if !@crashkernel_param || crash_value != @crashkernel_param_value
          crash_value = @crashkernel_param_value if Mode.autoinst

          if Mode.update
            if Builtins.search(crash_value, "@") != nil
              tmp_crash_value = Builtins.splitstring(crash_value, "@")
              crash_value = Ops.get(tmp_crash_value, 0, "")
              Builtins.y2milestone(
                "Delete offset crashkernel value: %1",
                crash_value
              )
            end
          end

          Bootloader.modify_kernel_params(:common, :xen_guest, :recovery, "crashkernel" => crash_value)
          old_progress = Progress.set(false)
          Bootloader.Write
          Progress.set(old_progress)
          # Popup::Message(crash_value);
          Builtins.y2milestone(
            "[kdump] (WriteKdumpBootParameter) adding chrashkernel option with value : %1",
            crash_value
          )
          if Mode.normal
            Popup.Message(_("To apply changes a reboot is necessary."))
          end

          Service.Enable(KDUMP_SERVICE_NAME)
          return result
        end

        # start kernel-kdump at boot
        Service.Enable(KDUMP_SERVICE_NAME)

        Service.Restart(KDUMP_SERVICE_NAME) if Service.Status(KDUMP_SERVICE_NAME) == 0
      else
        if @crashkernel_param
          #delete crashkernel paramter from bootloader
          Bootloader.modify_kernel_params(:common, :xen_guest, :recovery, "crashkernel" => :missing)
          old_progress = Progress.set(false)
          Bootloader.Write
          Progress.set(old_progress)
          if Mode.normal
            Popup.Message(_("To apply changes a reboot is necessary."))
          end
        end
        Service.Disable(KDUMP_SERVICE_NAME)
        Service.Stop(KDUMP_SERVICE_NAME) if Service.Status(KDUMP_SERVICE_NAME) == 0
        return result
      end
      true
    end



    # Read all kdump settings
    # @return true on success
    def Read
      # Kdump read dialog caption
      caption = _("Initializing kdump Configuration")
      steps = 4

      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/4
          _("Reading the config file..."),
          # Progress stage 3/4
          _("Reading kernel boot options..."),
          # Progress stage 4/4
          _("Reading available memory...")
        ],
        [
          # Progress step 1/4
          _("Reading the config file..."),
          # Progress step 2/4
          _("Reading partitions of disks..."),
          # Progress finished 3/4
          _("Reading available memory..."),
          # Progress finished 4/4
          Message.Finished
        ],
        ""
      )

      # read database
      return false if Abort()
      Progress.NextStage
      # Error message
      if !ReadKdumpSettings()
        Report.Error(_("Cannot read config file /etc/sysconfig/kdump"))
      end

      # read another database
      return false if Abort()
      Progress.NextStep
      # Error message
      if !ReadKdumpKernelParam()
        Report.Error(_("Cannot read kernel boot options."))
      end

      # read another database
      return false if Abort()
      Progress.NextStep
      # Error message
      Report.Error(_("Cannot read available memory.")) if !ReadAvailableMemory()

      return false if Abort()
      # Progress finished
      Progress.NextStage

      return false if Abort()
      @modified = false
      true
    end

    # Update crashkernel argument during update of OS
    # @return true on success

    def Update
      Builtins.y2milestone("Update kdump settings")
      ReadKdumpKernelParam()
      WriteKdumpBootParameter()
      true
    end


    # Write all kdump settings
    # @return true on success
    def Write
      # Kdump read dialog caption
      caption = _("Saving kdump Configuration")

      #number of stages
      steps = 2
      if Mode.installation
        write_kdump = ProductFeatures.GetBooleanFeature(
          "globals",
          "enable_kdump"
        )
        if write_kdump == nil || !write_kdump
          Builtins.y2milestone("Installation doesn't support kdump.")
          return true
        end
      end

      if (Mode.installation || Mode.autoinst) && !@add_crashkernel_param
        Builtins.y2milestone(
          "Skip writing of configuration for kdump during installation"
        )
        return true
      end

      # We do not set help text here, because it was set outside
      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/2
          _("Write the settings"),
          # Progress stage 2/2
          _("Update boot options")
        ],
        [
          # Progress step 1/2
          _("Writing the settings..."),
          # Progress step 2/2
          _("Updating boot options..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )

      # write settings
      return false if Abort()
      Progress.NextStage
      # Error message
      if ! WriteKdumpSettings()
        Report.Error(_("Cannot write settings."))
        return false
      end

      # write/delete bootloader option for kernel "crashkernel"
      return false if Abort()
      Progress.NextStage
      # Error message
      if !WriteKdumpBootParameter()
        Report.Error(_("Adding crashkernel parameter to bootloader fault."))
      end

      return false if Abort()
      # Progress finished
      Progress.NextStage

      return false if Abort()
      true
    end

    # Adding necessary packages for installation
    #

    def AddPackages
      return unless Mode.installation

      @kdump_packages << "kexec-tools"
      @kdump_packages << (Arch.ppc64 ? "kernel-kdump" : "kdump")
    end

    # Propose global variables once...
    # after that remember user settings

    def ProposeGlobalVars
      if !@propose_called
        # propose disable kdump if PC has less than 1024MB RAM
        if Ops.less_than(@total_memory, 1024)
          @add_crashkernel_param = false
        else
          @add_crashkernel_param = true
        end

        @crashkernel_param = false
        # added defualt settings
        @KDUMP_SETTINGS = deep_copy(@DEFAULT_CONFIG)
      end
      @propose_called = true

      nil
    end


    # Check if user enabled kdump
    # if no deselect packages for installing
    # if yes add necessary packages for installation
    def CheckPackages
      # remove duplicates
      @kdump_packages.uniq!
      if !@add_crashkernel_param
        Builtins.y2milestone(
          "deselect packages for installation: %1",
          @kdump_packages
        )
        @kdump_packages.each do |p|
          PackagesProposal.RemoveResolvables("yast2-kdump", :package, [p])
        end
        if !@kdump_packages.empty?
          Builtins.y2milestone(
            "Deselected kdump packages for installation: %1",
            @kdump_packages
          )
        end
      else
        Builtins.y2milestone(
          "select packages for installation: %1",
          @kdump_packages
        )
        @kdump_packages.each do |p|
          PackagesProposal.AddResolvables("yast2-kdump", :package, [p])
        end
        if !@kdump_packages.empty?
          Builtins.y2milestone(
            "Selected kdump packages for installation: %1",
            @kdump_packages
          )
        end
      end

      nil
    end

    # Propose all kdump settings
    #
    def Propose
      Builtins.y2milestone("Proposing new settings of kdump")
      # read available memory
      ReadAvailableMemory()
      # set default values for global variables
      ProposeGlobalVars()
      ProposeAllocatedMemory()

      # add packages for installation
      AddPackages()

      # select packages for installation
      CheckPackages()

      nil
    end

    # Create a textual summary and a list of unconfigured cards
    # @return summary of the current configuration
    def Summary
      result = []
      result = Builtins.add(
        result,
        Builtins.sformat(
          _("Kdump status: %1"),
          @add_crashkernel_param ? _("enabled") : _("disabled")
        )
      )
      if @add_crashkernel_param
        result = Builtins.add(
          result,
          Builtins.sformat(
            _("Value of crashkernel option: %1"),
            BuildCrashkernelValue()
          )
        )
        result = Builtins.add(
          result,
          Builtins.sformat(
            _("Dump format: %1"),
            Ops.get(@KDUMP_SETTINGS, "KDUMP_DUMPFORMAT", "")
          )
        )
        result = Builtins.add(
          result,
          Builtins.sformat(
            _("Target of dumps: %1"),
            Ops.get(@KDUMP_SETTINGS, "KDUMP_SAVEDIR", "")
          )
        )
        result = Builtins.add(
          result,
          Builtins.sformat(
            _("Number of dumps: %1"),
            Ops.get(@KDUMP_SETTINGS, "KDUMP_KEEP_OLD_DUMPS", "")
          )
        )
      end
      deep_copy(result)
    end

    # bnc# 480466 - fix problem with validation autoyast profil
    # Function filters keys for autoyast profil
    #
    # @param map <string, string > KDUMP_SETTINGS
    # @return [Hash{String => String}] filtered KDUMP_SETTINGS by DEFAULT_CONFIG

    def filterExport(settings)
      settings = deep_copy(settings)
      ret = {}
      keys = Convert.convert(
        Map.Keys(@DEFAULT_CONFIG),
        :from => "list",
        :to   => "list <string>"
      )
      ret = Builtins.filter(settings) do |key, value|
        next true if Builtins.contains(keys, key)
      end

      deep_copy(ret)
    end

    # Export kdump settings to a map
    # @return kdump settings
    def Export
      out = {
        "crash_kernel"     => BuildCrashkernelValue(),
        "add_crash_kernel" => @add_crashkernel_param,
        "general"          => filterExport(@KDUMP_SETTINGS)
      }

      Builtins.y2milestone("Kdump exporting settings: %1", out)
      deep_copy(out)
    end

    # Import settings from a map
    # @param [Hash] settings map of kdump settings
    # @return [Boolean] true on success
    def Import(settings)
      settings = deep_copy(settings)
      Builtins.y2milestone("Importing settings for kdump")
      @crashkernel_param_value = Ops.get_string(settings, "crash_kernel", "")
      @add_crashkernel_param = Ops.get_boolean(
        settings,
        "add_crash_kernel",
        false
      )
      result = true
      my_import_map = Ops.get_map(settings, "general", {})
      Builtins.foreach(Map.Keys(@DEFAULT_CONFIG)) do |key|
        str_key = Builtins.tostring(key)
        val = Ops.get(my_import_map, str_key)
        Ops.set(@KDUMP_SETTINGS, str_key, val) if val != nil
        if val == nil
          Ops.set(@KDUMP_SETTINGS, str_key, Ops.get(@DEFAULT_CONFIG, str_key))
        end
      end
      if Builtins.haskey(settings, "crash_kernel") ||
          Builtins.haskey(settings, "add_crash_kernel") ||
          Ops.greater_than(Builtins.size(my_import_map), 0)
        @import_called = true
      end
      result
    end

    # Returns whether FADump (Firmware assisted dump) is supported
    # by the current system
    #
    # @return [Boolean] is supported
    def fadump_supported?
      Arch.ppc64
    end

    # Sets whether to use FADump (Firmware assisted dump)
    #
    # @param [Boolean] new state
    # @return [Boolean] whether successfully set
    def use_fadump(new_value)
      # Trying to use fadump on unsupported hardware
      if !fadump_supported? && new_value
        Builtins.y2milestone("FADump is not supported on this hardware")
        Report.Error(_("Cannot use Firmware-assisted dump.\nIt is not supported on this hardware."))
        return false
      end

      @KDUMP_SETTINGS[FADUMP_KEY] = (new_value ? "yes" : "no")
      true
    end

    # Returns whether FADump (Firmware assisted dump) is currently in use
    #
    # @return [Boolean] currently in use
    def using_fadump?
      @KDUMP_SETTINGS[FADUMP_KEY] == "yes"
    end

    # Has the using_fadump? been changed?
    #
    # @return [Boolean] whether changed
    def using_fadump_changed?
      @initial_kdump_settings[FADUMP_KEY] != @KDUMP_SETTINGS[FADUMP_KEY]
    end

    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :SetModified, :type => "void ()"
    publish :variable => :modified, :type => "boolean"
    publish :variable => :proposal_valid, :type => "boolean"
    publish :variable => :available_partitions, :type => "list <string>"
    publish :variable => :propose_called, :type => "boolean"
    publish :variable => :uknown_fs_partitions, :type => "list <string>"
    publish :variable => :total_memory, :type => "integer"
    publish :variable => :crashkernel_list_ranges, :type => "boolean"
    publish :variable => :kdump_packages, :type => "list <string>"
    publish :variable => :crashkernel_param, :type => "boolean"
    publish :variable => :add_crashkernel_param, :type => "boolean"
    publish :variable => :allocated_memory, :type => "string"
    publish :variable => :import_called, :type => "boolean"
    publish :variable => :write_only, :type => "boolean"
    publish :variable => :AbortFunction, :type => "boolean ()"
    publish :variable => :DEFAULT_CONFIG, :type => "map <string, string>"
    publish :variable => :KDUMP_SETTINGS, :type => "map <string, string>"
    publish :function => :Abort, :type => "boolean ()"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Update, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :CheckPackages, :type => "void ()"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :Export, :type => "map ()"
    publish :function => :Import, :type => "boolean (map)"
  end

  Kdump = KdumpClass.new
  Kdump.main
end
