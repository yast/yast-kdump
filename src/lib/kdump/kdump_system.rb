require "yast"

module Yast
  Yast.import "Arch"

  class KdumpSystem
    MiB_SIZE = 1048576
    HYPER_TYPE_FILE = "/sys/hypervisor/type"
    HYPER_FEATURES_FILE = "/sys/hypervisor/properties/features"
    XENFEAT_DOM0 = 11

    # Checks whether Firmware-Assisted Dump is supported by the system
    def supports_fadump?
      Arch.ppc64
    end

    # Checks whether the usage of high memory is supported in the crashkernel
    # bootloader param
    def supports_high_mem?
      Arch.x86_64
    end

    # Check whether the system supports kdump
    #
    # See bsc#952253. Kdump cannot work in DomU
    def supports_kdump?
      return @supports_kdump unless @supports_kdump.nil?
      @supports_kdump = !domU?
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
      resource = probe.first["resource"]
      @reported_memory = resource["phys_mem"][0]["range"] / MiB_SIZE
    end

  private

    # Checks whether the bit at a given position is set
    def bit_set?(number, position)
      number & (1 << position) != 0
    end

    # Checks whether the system is a DomU
    #
    # See bsc#952253 for the rationale of the implementation
    def domU?
      domU = false
      type = SCR.Read(Path.new(".target.string"), HYPER_TYPE_FILE)
      # Check if the system is a Xen domain
      if type && type.strip.downcase == "xen"
        features = SCR.Read(Path.new(".target.string"), HYPER_FEATURES_FILE)
        # Check if the system is DomU (i.e. is not Dom0)
        if features && !bit_set?(features.strip.to_i(16), XENFEAT_DOM0)
          domU = true
        end
      end
      domU
    end
  end
end
