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
require "kdump/kdump_system"
require "kdump/kdump_calibrator"

require "shellwords"

module Yast
  class KdumpClass < Module
    include Yast::Logger

    FADUMP_KEY = "KDUMP_FADUMP".freeze
    KDUMP_SERVICE_NAME = "kdump".freeze
    KDUMP_PACKAGES = ["kexec-tools", "kdump"].freeze
    TEMPORARY_CONFIG_FILE = "/var/lib/YaST2/kdump.sysconfig".freeze
    TEMPORARY_CONFIG_PATH = Path.new(".temporary.sysconfig.kdump")

    # Space on disk reserved for dump additionally to memory size in bytes
    # @see FATE #317488
    RESERVED_DISK_SPACE_BUFFER_B = 4 * (1024**3)

    def main
      textdomain "kdump"

      Yast.import "Arch"
      Yast.import "Bootloader"
      Yast.import "Directory"
      Yast.import "FileUtils"
      Yast.import "Map"
      Yast.import "Message"
      Yast.import "Mode"
      Yast.import "Package"
      Yast.import "PackagesProposal"
      Yast.import "Popup"
      Yast.import "ProductControl"
      Yast.import "ProductFeatures"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Service"
      Yast.import "SpaceCalculation"
      Yast.import "String"
      Yast.import "Summary"

      reset
    end

    def reset
      # Data was modified?
      @modified = false

      # kdump config file

      @kdump_file = "/etc/sysconfig/kdump"

      @proposal_valid = false

      # Boolean option indicates that "crashkernel" includes
      # several values for the same kind of memory (low, high)
      # or several ranges in one of the values
      #
      # boolean true if there are several ranges (>1) or overriden values
      @crashkernel_list_ranges = false

      #  list of packages for installation
      @kdump_packages = []

      # Boolean option indicates kernel parameter
      # "crashkernel"
      #
      # boolean true if kernel parameter is set
      @crashkernel_param = false

      # Array (or String) with the values of the kernel parameter
      # "crashkernel"
      # It can also contain :missing or :present.
      # See Yast::Bootloader.kernel_param for details about those special values
      #
      # array values of kernel parameter
      @crashkernel_param_values = []

      # array values of kernel parameter for Xen hypervisor
      # see @crashkernel_param_values for details
      @crashkernel_xen_param_values = []

      # Boolean option indicates add kernel param
      # "crashkernel"
      #
      # boolean true if kernel parameter will be add
      @add_crashkernel_param = false

      # Set of values (high and low) for allocation of memory for boot param
      # "crashkernel"
      #
      # hash with up to two keys (:low and :high) and string values
      @allocated_memory = {}

      # Boolean option indicates that Import()
      # was called and data was proposed
      #
      # boolean true if import was called with data

      @import_called = false

      # Write only, used during autoinstallation/autoupgrade.
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
        "KDUMP_CPUS"               => "32",
        "KDUMP_COMMANDLINE"        => "",
        "KDUMP_COMMANDLINE_APPEND" => "",
        "KDUMP_AUTO_RESIZE"        => "false",
        "KEXEC_OPTIONS"            => "",
        "KDUMP_IMMEDIATE_REBOOT"   => "true",
        "KDUMP_TRANSFER"           => "",
        "KDUMP_SAVEDIR"            => "file:///var/crash",
        "KDUMP_KEEP_OLD_DUMPS"     => "0",
        "KDUMP_FREE_DISK_SIZE"     => "64",
        "KDUMP_VERBOSE"            => "0",
        "KDUMP_DUMPLEVEL"          => "31",
        "KDUMP_DUMPFORMAT"         => "compressed",
        "KDUMP_CONTINUE_ON_ERROR"  => "true",
        "KDUMP_REQUIRED_PROGRAMS"  => "",
        "KDUMP_PRESCRIPT"          => "",
        "KDUMP_POSTSCRIPT"         => "",
        "KDUMP_NETCONFIG"          => "auto",
        "KDUMP_NET_TIMEOUT"        => "30",
        "KDUMP_SMTP_SERVER"        => "",
        "KDUMP_SMTP_USER"          => "",
        "KDUMP_SMTP_PASSWORD"      => "",
        "KDUMP_NOTIFICATION_TO"    => "",
        "KDUMP_NOTIFICATION_CC"    => "",
        "KDUMP_HOST_KEY"           => ""
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
      return @AbortFunction.call == true unless @AbortFunction.nil?

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
      unless FileUtils.Exists(target)
        Builtins.y2error("Target %1 doesn't exist", target)
        return false
      end

      unless FileUtils.Exists("/bin/chmod")
        Builtins.y2error("tool: /bin/chmod not found")
        return false
      end

      cmd = Builtins.sformat("/bin/chmod %1 %2", permissions.shellescape, target.shellescape)
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

      if Ops.get(@KDUMP_SETTINGS, "KDUMP_SAVEDIR", "").include?("file") ||
          Ops.get(@KDUMP_SETTINGS, "KDUMP_SAVEDIR", "").include?("nfs") ||
          Ops.get(@KDUMP_SETTINGS, "KDUMP_SAVEDIR", "") == ""
        return false
      end

      return false unless Ops.get(@KDUMP_SETTINGS, "KDUMP_SAVEDIR", "").include?("@")

      temp = Builtins.splitstring(
        Ops.get(@KDUMP_SETTINGS, "KDUMP_SAVEDIR", ""),
        "@"
      )
      position = Builtins.findlastof(Ops.get(temp, 0, ""), ":")
      return false if position.nil?

      # if there is 2 times ":" -> it means that password is defined
      # for example cifs://login:password@server....
      position > 6
    end

    # Read current kdump configuration
    #
    # read kernel parameter "crashkernel"
    #  @return [Boolean] successfull
    def ReadKdumpKernelParam
      result = Bootloader.kernel_param(:common, "crashkernel")
      xen_result = Bootloader.kernel_param(:xen_host, "crashkernel")
      # result could be [String,Array,:missing,:present]
      # String   - the value of the only occurrence
      # Array    - the values of the multiple occurrences
      # :missing - crashkernel is missed
      # :present - crashkernel is defined but no value is available

      if result == :missing
        @crashkernel_param = false
        @add_crashkernel_param = false
      else
        @crashkernel_param = true
        @add_crashkernel_param = true
      end

      if [:missing, :present].include?(result)
        @crashkernel_param_values = result
      else
        # Let's make sure it's an array
        # filtering nils and empty entries bnc#991140
        @crashkernel_param_values = Array(result).compact.reject(&:empty?)
        # Read the current value only if crashkernel parameter is set.
        # (bnc#887901)
        @allocated_memory = get_allocated_memory(@crashkernel_param_values)
      end

      @crashkernel_xen_param_values = if [:missing, :present].include?(xen_result)
        xen_result
      else
        # Let's make sure it's an array
        # filtering nils and empty entries bnc#991140
        Array(xen_result).compact.reject(&:empty?)
      end

      true
    end

    # Returns the KdumpSystem instance
    def system
      @system ||= Yast::KdumpSystem.new
    end

    def write_temporary_config_file
      SCR.RegisterAgent(TEMPORARY_CONFIG_PATH,
        term(:ag_ini,
          term(:SysConfigFile, TEMPORARY_CONFIG_FILE)))
      WriteKdumpSettingsTo(TEMPORARY_CONFIG_PATH, TEMPORARY_CONFIG_FILE)
      SCR.UnregisterAgent(TEMPORARY_CONFIG_PATH)
    end

    # Return the Kdump calibrator instance
    #
    # @return [Yast::KdumpCalibrator] Calibrator instance
    def calibrator
      return @calibrator unless @calibrator.nil?

      if Mode.normal
        @calibrator = Yast::KdumpCalibrator.new
      else
        write_temporary_config_file
        @calibrator = Yast::KdumpCalibrator.new(TEMPORARY_CONFIG_FILE)
      end
    end

    # Returns the Kdump memory limits
    #
    # It relies on the calibrator but it adjust the low memory limits when using firmware-assisted
    # dumps. The reason is that those limits might contradict the recommended value. See
    # jsc#SLE-21644 for more information.
    #
    # @return [Hash] The hash contains the following keys: :min_low, :max_low,
    #   :default_low, :min_high, :max_high, :default_high, :min_fadump,
    #    :max_fadump, :default_fadump
    def memory_limits
      calibrator.memory_limits
    end

    # Propose reserved/allocated memory
    # Store the result as a hash to @allocated_memory
    # @return [Boolean] true, always successful
    def ProposeAllocatedMemory
      # only propose once
      return true unless @allocated_memory.empty?

      @allocated_memory = { low: calibrator.default_low.to_s, high: calibrator.default_high.to_s }
      Builtins.y2milestone(
        "[kdump] allocated memory if not set in \"crashkernel\" param: %1",
        @allocated_memory
      )
      true
    end

    # Returns total size of physical memory in MiB
    def total_memory
      calibrator.total_memory
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
      # when /boot is ro, we need to use transactional update to be able to
      # rebuild initrd. In the end tu script below is used, but needs sauce
      # around
      if Package.IsTransactionalSystem
        update_initrd_with("transactional-update --continue kdump")
      else
        update_initrd_with("mkdumprd")
      end
    end

    # @param update_command [String] a command for .target.bash
    # @return [Boolean] whether successful
    def update_initrd_with(update_command)
      update_logfile = File.join(Directory.logdir, "y2logmkinitrd")

      run_command = update_command + " >> #{update_logfile.shellescape} 2>&1"
      y2milestone("Running command: #{run_command}")
      ret = SCR.Execute(path(".target.bash"), run_command)

      if ret != 0
        y2error("Error updating initrd, see #{update_logfile} or call #{update_command} manually")
        Report.Error(format(_(
          "Error updating initrd while calling '%{cmd}'.\n" \
          "See %{log} for details."
        ), :cmd => update_command, :log => update_logfile))
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

      update_initrd
    end

    # Write kdump boot arguments - crashkernel and fadump
    # set kdump start at boot
    #
    #  @return [Boolean] successfull
    def WriteKdumpBootParameter
      reboot_needed = using_fadump_changed?

      # First, write or remove the fadump param if needed
      write_fadump_boot_param

      # Then, do the same for the crashkernel param
      #
      # If we need to add crashkernel param
      if @add_crashkernel_param
        if Mode.autoinst || Mode.autoupgrade
          # Use the value(s) read by import
          crash_values = @crashkernel_param_values
          crash_xen_values = @crashkernel_xen_param_values
          # Always write the value
          skip_crash_values = false
        else
          # Calculate the param values based on @allocated_memory
          crash_values = crash_kernel_values
          crash_xen_values = crash_xen_kernel_values
          remove_offsets!(crash_values) if Mode.update
          remove_offsets!(crash_xen_values) if Mode.update
          # Skip writing of param if it's already set to the desired values
          skip_crash_values = @crashkernel_param && @crashkernel_param_values == crash_values
          skip_crash_values &&= @crashkernel_xen_param_values && @crashkernel_xen_param_values == crash_xen_values
        end

        if skip_crash_values
          # start kdump at boot
          Service.Enable(KDUMP_SERVICE_NAME)
          Service.Restart(KDUMP_SERVICE_NAME) if Service.active?(KDUMP_SERVICE_NAME)
        else
          Bootloader.modify_kernel_params(:common, :recovery, "crashkernel" => crash_values)
          Bootloader.modify_kernel_params(:xen_host, "crashkernel" => crash_xen_values)
          # do mass write in installation to speed up, so skip this one
          old_progress = Progress.set(false)
          # Has also to be called while installation because Kdbump finish will be called
          # after Bootloader finish. (bsc#1249370, bsc#1226676)
          Bootloader.Write
          Progress.set(old_progress)
          Builtins.y2milestone(
            "[kdump] (WriteKdumpBootParameter) adding crashkernel options with values: %1",
            crash_values
          )
          Builtins.y2milestone(
            "[kdump] (WriteKdumpBootParameter) adding xen crashkernel options with values: %1",
            crash_xen_values
          )
          reboot_needed = true
          Service.Enable(KDUMP_SERVICE_NAME)
        end
      else
        # If we don't need the param but it is there
        if @crashkernel_param
          # delete crashkernel parameter from bootloader
          Bootloader.modify_kernel_params(:common, :xen_guest, :recovery, :xen_host, "crashkernel" => :missing)
          old_progress = Progress.set(false)
          # Has also to be called while installation because Kdbump finish will be called
          # after Bootloader finish. (bsc#1249370, bsc#1226676)
          Bootloader.Write
          Progress.set(old_progress)
          reboot_needed = true
        end
        Service.Disable(KDUMP_SERVICE_NAME)
        Service.Stop(KDUMP_SERVICE_NAME) if Service.active?(KDUMP_SERVICE_NAME)
      end

      if reboot_needed && Mode.normal && !Mode.commandline
        Popup.Message(_("To apply changes a reboot is necessary."))
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
          _("Calculating memory limits...")
        ],
        [
          # Progress step 1/4
          _("Reading the config file..."),
          # Progress step 2/4
          _("Reading partitions of disks..."),
          # Progress finished 3/4
          _("Reading available memory and calibrating usage..."),
          # Progress finished 4/4
          Message.Finished
        ],
        ""
      )

      # read database
      return false if Abort()

      Progress.NextStage
      # Error message
      Report.Error(_("Cannot read config file /etc/sysconfig/kdump")) unless ReadKdumpSettings()

      # read another database
      return false if Abort()

      Progress.NextStep
      # Error message
      Report.Error(_("Cannot read kernel boot options.")) unless ReadKdumpKernelParam()

      # read another database
      return false if Abort()

      Progress.NextStep
      ProposeAllocatedMemory()
      # Error message
      Report.Error(_("Cannot read available memory.")) if total_memory.zero?

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
      ReadKdumpKernelParam() unless Mode.autoupgrade
      WriteKdumpBootParameter()
      true
    end

    # Write all kdump settings
    # @return true on success
    def Write
      # Kdump read dialog caption
      caption = _("Saving kdump Configuration")

      # number of stages
      steps = 2
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
      unless WriteKdumpSettings()
        Report.Error(_("Cannot write settings."))
        return false
      end

      # write/delete bootloader options for kernel - "crashkernel" and "fadump"
      return false if Abort()

      Progress.NextStage
      # Error message
      unless WriteKdumpBootParameter()
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

      @kdump_packages.concat KDUMP_PACKAGES
    end

    # Proposes default state of kdump (enabled/disabled)
    #
    # @return [Boolean] the default proposed state

    def ProposeCrashkernelParam
      # proposing disabled kdump if product wants it (bsc#1071242)
      if !ProductFeatures.GetBooleanFeature("globals", "enable_kdump")
        log.info "Kdump disabled in control file"
        false
      # proposing disabled kdump if PC has less than 1024MB RAM
      elsif total_memory < 1024
        log.info "not enough memory - kdump proposed as disabled"
        false
      # proposing disabled kdump on aarch64 (bsc#989321) - kdump not implemented
      elsif Arch.aarch64
        log.info "aarch64 - kdump proposed as disabled"
        false
      else
        true
      end
    end

    # Propose global variables once...
    # after that remember user settings

    def ProposeGlobalVars
      # Settings have not been imported by AutoYaST and have not already
      # been changed. (bnc#930950, bnc#995750, bnc#890719).
      if !@modified && !@import_called
        # added default settings
        @KDUMP_SETTINGS = deep_copy(@DEFAULT_CONFIG)
        @add_crashkernel_param = ProposeCrashkernelParam()
        @crashkernel_param = false
      end

      nil
    end

    # Check if user enabled kdump
    # if no deselect packages for installing
    # if yes add necessary packages for installation
    def CheckPackages
      # remove duplicates
      @kdump_packages.uniq!
      if @add_crashkernel_param
        Builtins.y2milestone(
          "select packages for installation: %1",
          @kdump_packages
        )
        @kdump_packages.each do |p|
          PackagesProposal.AddResolvables("yast2-kdump", :package, [p])
        end
        unless @kdump_packages.empty?
          Builtins.y2milestone(
            "Selected kdump packages for installation: %1",
            @kdump_packages
          )
        end
      else
        Builtins.y2milestone(
          "deselect packages for installation: %1",
          @kdump_packages
        )
        @kdump_packages.each do |p|
          PackagesProposal.RemoveResolvables("yast2-kdump", :package, [p])
        end
        unless @kdump_packages.empty?
          Builtins.y2milestone(
            "Deselected kdump packages for installation: %1",
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
      # set default values for global variables
      ProposeGlobalVars()
      # check available memory and execute the calibrator
      ProposeAllocatedMemory()
      # add packages for installation
      AddPackages()
      # select packages for installation
      CheckPackages()

      nil
    end

    # Create a textual summary
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
            _("Value(s) of crashkernel option: %1"),
            crash_kernel_values.join(" ")
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

    # Returns available space (in bytes) for Kernel dump according to KDUMP_SAVEDIR option
    # only local space is evaluated (starts with file://)
    #
    # @return [Integer] free space in bytes or nil if filesystem is not local or no
    #                   packages proposal is made yet
    def free_space_for_dump_b
      kdump_savedir = @KDUMP_SETTINGS.fetch("KDUMP_SAVEDIR", "file:///var/log/dump").dup
      log.info "Using savedir #{kdump_savedir}"

      if kdump_savedir.start_with?("/")
        log.warn "Using old format"
      elsif kdump_savedir.start_with?("file://")
        kdump_savedir.sub!(/file:\/\//, "")
      else
        log.info "KDUMP_SAVEDIR #{kdump_savedir.inspect} is not local"
        return nil
      end

      # unified format of directory
      kdump_savedir = format_dirname(kdump_savedir)

      partitions_info = SpaceCalculation.GetPartitionInfo()
      if partitions_info.empty?
        log.warn "No partitions info available"
        return nil
      end

      log.info "Disk usage: #{partitions_info}"
      # Create a hash of partitions and their free space { partition => free_space, ... }
      # "name" usually does not start with "/", but does so for root filesystem
      # File.join ensures that paths do not contain dulplicit "/" characters
      partitions_info = partitions_info.map do |partition|
        { format_dirname(partition["name"]) => partition["free"] }
      end.inject(:merge)

      # All partitions matching KDUMP_SAVEDIR
      matching_partitions = partitions_info.select do |partition, _space|
        kdump_savedir.start_with?(partition)
      end

      # The longest match
      partition = matching_partitions.keys.max_by { |partiton| partiton.length }
      free_space = matching_partitions[partition]

      if free_space.nil? || !free_space.is_a?(::Integer)
        log.warn "Available space for partition #{partition} not provided (#{free_space.inspect})"
        return nil
      end

      # packager counts in kB, we need bytes
      free_space *= 1024
      log.info "Available space for dump: #{free_space} bytes in #{partition} directory"

      free_space
    end

    # Returns disk space in bytes requested for kernel dump (as defined in FATE#317488)
    #
    # @return [Integer] bytes
    def space_requested_for_dump_b
      # Total memory is in MB, converting to bytes
      (total_memory * (1024**2)) + RESERVED_DISK_SPACE_BUFFER_B
    end

    # Returns installation proposal warning as part of the MakeProposal map result
    # includes 'warning' and 'warning_level' keys
    #
    # @param returns [Hash] with warnings
    def proposal_warning
      return {} unless @add_crashkernel_param

      free_space = free_space_for_dump_b
      requested_space = space_requested_for_dump_b

      log.info "Free: #{free_space}, requested: #{requested_space}"
      return {} if free_space.nil? || requested_space.nil?

      warning = {}
      warning_string = ""

      if free_space < requested_space
        # TRANSLATORS: warning message in installation proposal. Do not translate %{requested} and
        # %{available} - they are replaced with actual sizes later.
        warning_string = format(_(
          "Warning! There might not be enough free space to have kdump enabled. " \
          "%{required} required for saving a kernel dump, but only %{available} are available."
        ), required: String.FormatSizeWithPrecision(requested_space, 2, true), available: String.FormatSizeWithPrecision(free_space, 2, true))
      end

      unless warning_string.empty?
        warning = {
          "warning_level" => :warning,
          "warning"       => "<ul><li>" + warning_string + "</li></ul>"
        }
      end

      log.warn warning["warning"] if warning["warning"]
      warning
    end

    # bnc# 480466 - fix problem with validation autoyast profil
    # Function filters keys for autoyast profil
    #
    # @param map <string, string > KDUMP_SETTINGS
    # @return [Hash{String => String}] filtered KDUMP_SETTINGS by DEFAULT_CONFIG

    def filterExport(settings)
      settings = deep_copy(settings)
      keys = Map.Keys(@DEFAULT_CONFIG)
      Builtins.filter(settings) do |key, _value|
        Builtins.contains(keys, key)
      end
    end

    # Export kdump settings to a map
    # @return kdump settings
    def Export
      if @add_crashkernel_param
        crash_kernel = crash_kernel_values
        crash_kernel = crash_kernel[0] if crash_kernel.size == 1
        crash_xen_kernel = crash_xen_kernel_values
        crash_xen_kernel = crash_xen_kernel[0] if crash_xen_kernel.size == 1
        out = {
          "crash_kernel"     => crash_kernel,
          "crash_xen_kernel" => crash_xen_kernel,
          "add_crash_kernel" => true,
          "general"          => filterExport(@KDUMP_SETTINGS)
        }
      else
        out = { "add_crash_kernel" => false }
      end

      Builtins.y2milestone("Kdump exporting settings: %1", out)
      deep_copy(out)
    end

    # Import settings from a map
    # @param [Hash, nil] settings map of kdump settings
    # @return [Boolean] true on success
    def Import(settings)
      settings ||= {}
      Builtins.y2milestone("Importing settings for kdump #{settings.inspect}")

      my_import_map = Ops.get_map(settings, "general", {})
      @DEFAULT_CONFIG.each_pair do |key, def_value|
        value = my_import_map[key]
        @KDUMP_SETTINGS[key] = value.nil? ? def_value : value
      end

      if settings.key?("crash_kernel")
        # Make sure it's an array
        @crashkernel_param_values = Array(settings.fetch("crash_kernel", ""))
        # In order not to overwrite the values by the proposal we will have to set
        # according allocated memory too. (bnc#995750)
        @allocated_memory = get_allocated_memory(@crashkernel_param_values)
      else
        # Taking proposed values (bnc#997448)
        ProposeAllocatedMemory()
        # Make sure it's an array
        @crashkernel_param_values = Array(crash_kernel_values)
      end

      @crashkernel_xen_param_values = if settings.key?("crash_xen_kernel")
        # Make sure it's an array
        Array(settings.fetch("crash_xen_kernel", ""))
      else
        Array(crash_xen_kernel_values)
      end

      @add_crashkernel_param = if settings.key?("add_crash_kernel")
        settings["add_crash_kernel"]
      else
        ProposeCrashkernelParam()
      end

      if settings.key?("crash_kernel") || settings.key?("add_crash_kernel") ||
          !my_import_map.empty?
        @import_called = true
      end

      true
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

      @KDUMP_SETTINGS[FADUMP_KEY] = (new_value ? "true" : "false")
      true
    end

    # Returns whether FADump (Firmware assisted dump) is currently in use
    #
    # @return [Boolean] currently in use
    def using_fadump?
      ["yes", "true", "1"].include?(@KDUMP_SETTINGS[FADUMP_KEY])
    end

    # Has the using_fadump? been changed?
    #
    # @return [Boolean] whether changed
    def using_fadump_changed?
      @initial_kdump_settings[FADUMP_KEY] != @KDUMP_SETTINGS[FADUMP_KEY]
    end

    # Returns whether usage of high memory in the crashkernel bootloader param
    # is supported by the current system
    #
    # @return [Boolean] is supported
    def high_memory_supported?
      calibrator.high_memory_supported?
    end

    # Returns whether usage of fadump is supported by the current system
    #
    # @return [Boolean] is supported
    def fadump_supported?
      calibrator.fadump_supported?
    end

    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :SetModified, :type => "void ()"
    publish :variable => :modified, :type => "boolean"
    publish :variable => :proposal_valid, :type => "boolean"
    publish :function => :total_memory, :type => "integer ()"
    publish :variable => :crashkernel_list_ranges, :type => "boolean"
    publish :variable => :kdump_packages, :type => "list <string>"
    publish :variable => :crashkernel_param, :type => "boolean"
    publish :variable => :add_crashkernel_param, :type => "boolean"
    publish :variable => :allocated_memory, :type => "map"
    publish :function => :memory_limits, :type => "map ()"
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

    # Offer this to ensure backward compatibility
    def allocated_memory=(memory)
      @allocated_memory = if memory.is_a?(::String)
        if memory.empty?
          {}
        else
          { low: memory }
        end
      else
        memory
      end
    end

  private

    # Returns unified directory name with leading and ending "/"
    # for exact matching
    def format_dirname(dirname)
      "/#{dirname}/".gsub(/\/+/, "/")
    end

    # get allocated memory from the set of values of the crashkernel option
    #
    # each value can be a set of ranges (first range will be taken) or a
    # concrete value for high or low memory
    # syntax for ranges: 64M@16M or 128M-:64M@16M [(reserved_memory*2)-:reserved_memory]
    # syntax for concrete value: 64M or 64M,high or 64M,low
    #
    #  @param crash_values [Array<string>] list of values
    #  @return [Hash] values of allocated memory ({low: "64", high: "16"})
    def get_allocated_memory(crash_values)
      result = {}
      crash_values.each do |crash_value|
        pieces = crash_value.split(",")

        if pieces.last =~ /^(low|high)$/i
          key = pieces.last.downcase.to_sym
          @crashkernel_list_ranges ||= (pieces.size > 2)
        else
          key = :low
          @crashkernel_list_ranges ||= (pieces.size > 1)
        end
        # Skip everything but the first occurrence
        if result[key]
          @crashkernel_list_ranges = true
          next
        end

        range = pieces.first
        Builtins.y2milestone("The 1st range from crashkernel is %1", range)
        value = range.split(":").last.split("M").first
        result[key] = value
      end
      Builtins.y2milestone("Allocated memory is %1", result)
      result
    end

    # Build crashkernel values from allocated memory
    #
    # @return [Array<String>] list of values of crashkernel
    def crash_kernel_values
      # If the current values include "nasty" things and the user has not
      # overriden the value of @crashkernel_list_ranges to autorize the
      # modification.
      # The old value (ensuring the Array format) will be returned.
      if @crashkernel_list_ranges
        return Array(@crashkernel_param_values.to_s) if @crashkernel_param_values.is_a?(Symbol)

        return Array(@crashkernel_param_values.dup)
      end

      result = []
      if ["yes", "true", "1"].include?(@KDUMP_SETTINGS["KDUMP_AUTO_RESIZE"])
        maxsize = total_memory / 2
        if high_memory_supported?
          low = memory_limits[:default_low]
          high = memory_limits[:max_high]
          high = (maxsize - low.to_i).to_s if high.to_i > maxsize
        else
          high = memory_limits[:min_high]
          low = memory_limits[:max_low]
          low = maxsize.to_s if low.to_i > maxsize
        end
      else
        high = @allocated_memory[:high]
        low = @allocated_memory[:low]
      end
      result << "#{high}M,high" if high && high.to_i != 0
      # Add the ',low' suffix only there is a ',high' one
      result << (result.empty? ? "#{low}M" : "#{low}M,low") if low && low.to_i != 0

      log.info "built crashkernel values are #{result}"

      result
    end

    def crash_xen_kernel_values
      # If the current values include "nasty" things and the user has not
      # overriden the value of @crashkernel_list_ranges to autorize the
      # modification.
      # The old value (ensuring the Array format) will be returned.
      if @crashkernel_list_ranges
        if @crashkernel_xen_param_values.is_a?(Symbol)
          return Array(@crashkernel_xen_param_values.to_s)
        end

        return Array(@crashkernel_xen_param_values.dup)
      end

      result = []
      if ["yes", "true", "1"].include?(@KDUMP_SETTINGS["KDUMP_AUTO_RESIZE"])
        high = memory_limits[:default_high]
        low = memory_limits[:default_low]
      else
        high = @allocated_memory[:high]
        low = @allocated_memory[:low]
      end
      sum = 0
      sum += low.to_i if low
      sum += high.to_i if high

      result << "#{sum}M\\<4G" if sum != 0

      log.info "built xen crashkernel values are #{result}"

      result
    end

    # Removes offsets from all the crashkernel values
    #
    # Beware: not functional, it modifies the passed argument
    #
    # @param values [Array,Symbol] list of values or one of the special values
    #       returned by Bootloader.kernel_param
    def remove_offsets!(values)
      # It could also be :missing or :present
      return unless values.is_a?(Array)

      values.map! do |value|
        pieces = value.split("@")
        Builtins.y2milestone("Delete offset crashkernel value: %1", value) if pieces.size > 1
        pieces.first
      end
    end

    def write_fadump_boot_param
      return unless fadump_supported?

      # If fdump is selected and we want to enable kdump
      value = "on" if using_fadump? && @add_crashkernel_param
      value ||= :missing
      Bootloader.modify_kernel_params(:common, :recovery, "fadump" => value)
      Bootloader.Write unless Yast::Stage.initial # do mass write in installation to speed up
    end
  end

  Kdump = KdumpClass.new
  Kdump.main
end
