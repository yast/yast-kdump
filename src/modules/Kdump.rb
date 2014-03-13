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
    FADUMP_KEY = "KDUMP_FADUMP"
    KDUMP_SERVICE_NAME = "kdump.service"

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


      # String option identify which boot section was used
      # during boot process
      #
      # string value actual boot section

      @actual_boot_section = ""


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
        "KDUMP_DUMPLEVEL"          => "0",
        "KDUMP_DUMPFORMAT"         => "compressed", #or "ELF"
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


    # Compare boot section options with
    #
    # options from running kernel
    #  @return [Fixnum] return number of differences

    def CmpKernelAndBootOptions(kernel_option, boot_options)
      kernel_option = deep_copy(kernel_option)
      boot_options = deep_copy(boot_options)
      result = Builtins.size(kernel_option)
      dif_size = Ops.subtract(
        Builtins.size(boot_options),
        Builtins.size(kernel_option)
      )
      dif_size = Ops.multiply(dif_size, -1) if Ops.less_than(dif_size, 0)
      Builtins.foreach(kernel_option) do |option|
        if Builtins.contains(boot_options, option)
          result = Ops.subtract(result, 1)
        end
      end

      result = Ops.add(result, dif_size)
      result
    end


    # Function add into option from boot
    # section root device and vgamode
    #
    #  @return [Array<String>] boot section + root and vgamode


    def AddDeviceVgamode(section)
      section = deep_copy(section)
      tmp_boot_section = Builtins.tostring(Ops.get(section, "append"))
      # adding root device
      tmp_boot_section = Ops.add(
        Ops.add(tmp_boot_section, " root="),
        Builtins.tostring(Ops.get(section, "root"))
      )
      tmp_boot_section = Ops.add(
        Ops.add(tmp_boot_section, " vga="),
        Builtins.tostring(Ops.get(section, "vgamode"))
      )

      Builtins.splitstring(tmp_boot_section, " ")
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

    # Read actual boot section
    #
    # read kernal version and boot options
    #  @return [String] actual boot section


    def GetActualBootSection
      # read option from bootlaoder

      result = ""
      kernel_boot_options = ""
      min_dif_size = 1000
      if Mode.update
        result = Bootloader.getDefaultSection
        section_position = -1
        Builtins.foreach(BootCommon.sections) do |section|
          section_position = Ops.add(section_position, 1)
          name = Builtins.tostring(Ops.get(section, "name"))
          if name == result && Ops.get(section, "xen_append") != nil
            @section_pos = section_position
            @kernel_version = "xen"
          end
        end
        return result
      end

      # reading bootloader settings
      old_progress = Progress.set(false)
      Bootloader.Read
      Progress.set(old_progress)

      # reading kernel options
      command = "cat /proc/cmdline"
      options = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), command)
      )
      Builtins.y2milestone(
        "[kdump] (GetActualBootSection) command read boot options from kernel:  %1  output: %2",
        command,
        options
      )

      return "" if Ops.get(options, "exit") != 0

      kernel_boot_options = Builtins.tostring(Ops.get(options, "stdout"))

      # reading version of kernel
      command = "uname -r"
      options = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), command)
      )
      Builtins.y2milestone(
        "[kdump] (GetActualBootSection) command read kernel version:  %1  output: %2",
        command,
        options
      )

      return "" if Ops.get(options, "exit") != 0

      @kernel_version = Builtins.tostring(Ops.get(options, "stdout"))
      Builtins.y2milestone(
        "[kdump] (GetActualBootSection) kerne version: %1",
        @kernel_version
      )

      # boot sections from bootloader
      sects = deep_copy(BootCommon.sections)

      # deleting non linux sections
      sects = Builtins.filter(sects) { |s| !Builtins.haskey(s, "chainloader") }

      Builtins.y2milestone(
        "[kdump] (GetActualBootSection) BootCommon::sections only linux sections:  %1",
        sects
      )

      # find probably boot section, what was used during start-up
      Builtins.foreach(sects) do |section|
        image = Builtins.tostring(Ops.get(section, "image"))
        if image != nil
          command = Ops.add("/sbin/get_kernel_version ", image)
          options = Convert.to_map(
            SCR.Execute(path(".target.bash_output"), command)
          )

          if Ops.get(options, "exit") == 0
            ret = Builtins.tostring(Ops.get(options, "stdout"))

            if ret == @kernel_version
              #Popup::Message("hura!");
              value = CmpKernelAndBootOptions(
                Builtins.splitstring(kernel_boot_options, " "),
                AddDeviceVgamode(section)
              )
              if Ops.less_than(value, min_dif_size)
                min_dif_size = value
                result = Builtins.tostring(Ops.get(section, "name"))
              end
            end # end if (ret == kernel_version)
          end # end if (options["exit"]:nil ==  0)
        end # end of if (image != nil)
      end # end of foreach(map section, sects, {

      Builtins.y2milestone(
        "[kdump] (GetActualBootSection) selected boot section :  %1",
        result
      )
      result
    end

    # get value of crashkernel option
    # from XEN boot section
    #  @param string crashkernel=64M@16M
    #  @return [String] value of carshkernel option

    def getCrashKernelValue(crash)
      Builtins.y2milestone("crashkernel option %1", crash)
      result = ""
      if crash != "" || crash != nil
        position = Builtins.search(crash, "=")
        if position != nil
          result = Builtins.substring(crash, Ops.add(position, 1))
        else
          Builtins.y2error("Wrong crashkernel option!")
        end
      end
      Builtins.y2milestone("crashkernel value is %1", result)
      result
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
      # if user doesn't modified or select don't modify
      # return readed value
      return @crashkernel_param_value if @crashkernel_list_ranges

      crash_value = ""
      crash_value = Ops.add(@allocated_memory, "M")

      # bnc#563905 problem with offset in crashkernel
      if Arch.i386 || Arch.x86_64 || Arch.ia64 || Arch.ppc64
        Builtins.y2milestone(
          "i386, x86_64, ia64 and ppc64 platforms are without offset"
        )
      else
        if Mode.normal
          Popup.Error(
            _("Unsupported architecture, \"crashkernel\" was not added")
          )
        end
        Builtins.y2error("Unsupported platform/architecture...")
      end

      reserved_memory = Builtins.tostring(
        Ops.multiply(2, Builtins.tointeger(@allocated_memory))
      )


      crash_value = Ops.add(Ops.add(reserved_memory, "M-:"), crash_value)
      Builtins.y2milestone("builded crashkernel value is %1", crash_value)
      crash_value
    end

    # bnc #439881 - Don't use extended crashkernel syntax for Xen
    # Fuction convert extended crashkernel value to old style :Y@X
    #
    # @param string - extended value of crashkernel
    # @return [String] - old style value


    def convertCrashkernelForXEN(crash)
      crash_value = ""
      if crash != ""
        crash_value = Ops.add(getAllocatedMemory(crash), "M")
        # bnc#563905 problem with offset in crashkernel
        #if ((Arch::i386()) ||(Arch::x86_64()) || Arch::ppc64())
        #	crash_value = crash_value + "@16M";
      end
      Builtins.y2milestone(
        "Converting crashkernel value from: (%1) to :(%2)",
        crash,
        crash_value
      )
      crash_value
    end



    # Check if default boot section is Xen section
    # remember position of section (important for saving to xen_append)
    # @param string name of section

    def CheckXenDefault(act_boot_secion)
      if act_boot_secion != "" && act_boot_secion != nil
        section_position = -1
        Builtins.foreach(BootCommon.sections) do |section|
          section_position = Ops.add(section_position, 1)
          name = Builtins.tostring(Ops.get(section, "name"))
          type = Builtins.tostring(Ops.get(section, "type"))
          if name == act_boot_secion && type == "xen"
            @section_pos = section_position
            Builtins.y2milestone("default boot section is Xen...")
          end
        end
        if @section_pos == -1
          Builtins.y2milestone("default boot section is NOT Xen...")
        end
      end

      nil
    end

    # Read current kdump configuration
    # from XEN boot section
    # read kernel parameter "crashkernel"
    #  @return [Boolean] successfull


    def ReadXenKdumpKernelParam(act_boot_secion)
      crash = ""
      if @actual_boot_section == ""
        Builtins.y2milestone("Actual boot section was not found")
        @crashkernel_param = false
        @add_crashkernel_param = false
      else
        section_position = -1
        Builtins.foreach(BootCommon.sections) do |section|
          section_position = Ops.add(section_position, 1)
          name = Builtins.tostring(Ops.get(section, "name"))
          if name == act_boot_secion
            crash = Ops.get_string(section, "xen_append", "")
            @section_pos = section_position
          end
        end
      end

      if crash != ""
        xen_append = Builtins.splitstring(crash, " ")
        crash_arg = ""

        if Ops.greater_than(Builtins.size(xen_append), 1)
          Builtins.foreach(xen_append) do |key|
            crash_arg = key if Builtins.search(key, "crashkernel") != nil
          end
        else
          crash_arg = crash
        end

        if crash_arg != ""
          @crashkernel_param = true
          @add_crashkernel_param = true
          @crashkernel_param_value = getCrashKernelValue(crash_arg)
          @allocated_memory = getAllocatedMemory(@crashkernel_param_value)
        else
          @crashkernel_param = false
          @add_crashkernel_param = false
        end
      end

      true
    end


    # Read current kdump configuration
    #
    # read kernel parameter "crashkernel"
    #  @return [Boolean] successfull

    def ReadKdumpKernelParam
      @actual_boot_section = GetActualBootSection()

      if Builtins.search(@kernel_version, "xen") != nil
        return ReadXenKdumpKernelParam(@actual_boot_section)
      end


      if @actual_boot_section == ""
        @actual_boot_section = Bootloader.getDefaultSection
      end

      result = Bootloader.getKernelParam(@actual_boot_section, "crashkernel")

      #Popup::Message(result);
      if result == "false"
        @crashkernel_param = false
        @add_crashkernel_param = false
      else
        @crashkernel_param = true
        @add_crashkernel_param = true
      end

      @crashkernel_param_value = result
      if result != "false"
        @allocated_memory = getAllocatedMemory(@crashkernel_param_value)
      end

      true
    end

    TEMPORARY_CONFIG_FILE = "/var/lib/YaST2/kdump.sysconfig"

    def write_temporary_config_file
      # In inst_sys there is not kdump_file
      return unless FileUtils.Exists(@kdump_file)

      # FIXME parameterize Write instead of copying the old config
      # NOTE make sure we do not lose 600 mode (cp is ok)
      command = "cp #{@kdump_file} #{TEMPORARY_CONFIG_FILE}"
      retcode = SCR.Execute(path(".target.bash"), command)
      # if this fails the system is broken; SCR has logged the details
      raise "cannot copy files" if retcode != 0
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
      ProposeAllocatedMemory()
      true
    end



    # Read current kdump configuration
    #
    #  @return [Boolean] successfull
    def ReadKdumpSettings
      @KDUMP_SETTINGS = deep_copy(@DEFAULT_CONFIG)
      Builtins.foreach(SCR.Dir(path(".sysconfig.kdump"))) do |key|
        val = Convert.to_string(
          SCR.Read(Builtins.add(path(".sysconfig.kdump"), key))
        )
        Ops.set(@KDUMP_SETTINGS, key, val) if val != nil
      end

      debug_KDUMP_SETTINGS = deep_copy(@KDUMP_SETTINGS)

      # delete KDUMP_SAVEDIR - it can include password
      Ops.set(debug_KDUMP_SETTINGS, "KDUMP_SAVEDIR", "********")
      Ops.set(debug_KDUMP_SETTINGS, "KDUMP_SMTP_PASSWORD", "********")
      Builtins.y2milestone("-------------KDUMP_SETTINGS-------------------")
      Builtins.y2milestone(
        "kdump configuration has been read without value \"KDUMP_SAVEDIR\" and \"KDUMP_SMTP_PASSWORD\": %1",
        debug_KDUMP_SETTINGS
      )
      Builtins.y2milestone("---------------------------------------------")

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

    # Write current kdump configuration
    #
    #  @return [Boolean] successfull
    def WriteKdumpSettings
      debug_KDUMP_SETTINGS = deep_copy(@KDUMP_SETTINGS)
      # delete KDUMP_SAVEDIR - it can include password
      Ops.set(debug_KDUMP_SETTINGS, "KDUMP_SAVEDIR", "********")
      Ops.set(debug_KDUMP_SETTINGS, "KDUMP_SMTP_PASSWORD", "********")
      Builtins.y2milestone("-------------KDUMP_SETTINGS-------------------")
      Builtins.y2milestone(
        "kdump configuration for writing without value \"KDUMP_SAVEDIR\" and \"KDUMP_SMTP_PASSWORD\": %1",
        debug_KDUMP_SETTINGS
      )
      Builtins.y2milestone("---------------------------------------------")

      Builtins.foreach(@KDUMP_SETTINGS) do |option_key, option_val|
        SCR.Write(
          Builtins.add(path(".sysconfig.kdump"), option_key),
          option_val
        )
      end
      SCR.Write(path(".sysconfig.kdump"), nil)

      if using_fadump_changed? && ! update_initrd
        return false
      end

      if checkPassword
        Chmod(@kdump_file, "600")
      else
        Chmod(@kdump_file, "644")
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
      if Mode.installation
        Bootloader.Read
        @actual_boot_section = Bootloader.getDefaultSection
        CheckXenDefault(@actual_boot_section)
      end

      Builtins.y2milestone("Default boot section is %1", @actual_boot_section)
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

          # write crashkernel option to boot section
          if @section_pos == -1
            result = Bootloader.setKernelParam(
              @actual_boot_section,
              "crashkernel",
              crash_value
            )
          else
            Ops.set(
              BootCommon.sections,
              [@section_pos, "xen_append"],
              Ops.add("crashkernel=", convertCrashkernelForXEN(crash_value))
            )
            # added flag which means that section was changed bnc #432651
            Ops.set(BootCommon.sections, [@section_pos, "__changed"], true)
            result = true
            Builtins.y2milestone(
              "Write boot section to XEN boot section %1",
              Ops.get(BootCommon.sections, @section_pos)
            )
          end
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
          result = Bootloader.setKernelParam(
            @actual_boot_section,
            "crashkernel",
            "false"
          )
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
      if Mode.installation
        @kdump_packages = Builtins.add(@kdump_packages, "kexec-tools")
        @kdump_packages = Builtins.add(@kdump_packages, "yast2-kdump")
        if Arch.ppc64
          @kdump_packages = Builtins.add(@kdump_packages, "kernel-kdump")
        else
          @kdump_packages = Builtins.add(@kdump_packages, "kdump")
        end
      end

      nil
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
      @kdump_packages = Builtins.toset(@kdump_packages)
      if !@add_crashkernel_param
        Builtins.y2milestone(
          "deselect packages for installation: %1",
          @kdump_packages
        )
        pkg_deselect = false
        Builtins.foreach(@kdump_packages) do |p|
          PackagesProposal.RemoveResolvables("yast2-kdump", :package, [p])
          pkg_deselect = true
        end
        if pkg_deselect
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
        pkg_added = false
        Builtins.foreach(@kdump_packages) do |p|
          PackagesProposal.AddResolvables("yast2-kdump", :package, [p])
          pkg_added = true
        end
        if pkg_added
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
    publish :variable => :crashkernel_param_value, :type => "string"
    publish :variable => :add_crashkernel_param, :type => "boolean"
    publish :variable => :allocated_memory, :type => "string"
    publish :variable => :import_called, :type => "boolean"
    publish :variable => :actual_boot_section, :type => "string"
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
