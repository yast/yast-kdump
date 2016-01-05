require "yast"

module Yast
  Yast.import "Arch"

  class KdumpSystem
    MiB_SIZE = 1_048_576

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
    # See bsc#952253. Kdump cannot work in DomU
    #
    # @return [Boolean] true if kdump is supported, false otherwise
    def supports_kdump?
      !Arch.is_xenU
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
        @reported_memory = resource["phys_mem"][0]["range"] / MiB_SIZE
      else
        @reported_memory = 0
      end
    end
  end
end
