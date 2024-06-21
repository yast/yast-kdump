# ------------------------------------------------------------------------------
# Copyright (c) [2018] SUSE LLC
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

require "yast"
Yast.import "Arch"

module Yast
  # class to query system for supporting system depending features
  class KdumpSystem
    MIB_SIZE = 1_048_576

    # Checks whether Firmware-Assisted Dump is supported by the system
    #
    # @return [Boolean] true if FADump is supported, false otherwise
    def supports_fadump?
      Arch.ppc64
    end

    # Checks whether the usage of high memory is supported in the crashkernel
    # bootloader param
    #
    # @return [Boolean] true if 'high' is supported, false otherwise
    def supports_high_mem?
      Arch.x86_64
    end

    # Check whether the system supports kdump
    #
    # See bsc#952253. Kdump cannot work in a PV DomU
    #
    # @return [Boolean] true if kdump is supported, false otherwise
    def supports_kdump?
      !Arch.paravirtualized_xen_guest?
    end

    # Physical memory (in MiB) reported by the kernel.
    #
    # Calculating the total memory in a system with kdump enabled is tricky,
    # since the amount reported by the kernel by the normal methods will be
    # lower than the real total memory. Thus, use this method only if you don't
    # have a more precise method (like calling kdumptool) available
    def reported_memory
      return @reported_memory if @reported_memory

      probe = SCR.Read(Path.new(".probe.memory"))
      # SCR.Read should never return nil, but better safe than sorry
      if probe
        resource = probe.first["resource"]
        @reported_memory = resource["phys_mem"][0]["range"] / MIB_SIZE
      else
        @reported_memory = 0
      end
    end
  end
end
