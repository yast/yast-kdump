module Yast
  # This class tries to calibrate Kdump minimum, maximum and recommended values
  #
  # It relies on kdumptool but, if the tool is not available or does not work
  # as expected, tries to set up reasonable memory values on its own.
  class KdumpCalibrator
    include Yast::Logger

    LOW_MEM = 896
    MIN_LOW_DEFAULT = 72
    MiB_SIZE = 1048576

    KDUMPTOOL_CMD = "kdumptool %s calibrate"
    KDUMPTOOL_ARG = "--configfile '%s'"
    KEYS_MAP = {
      "Low"     => :default_low,
      "MinLow"  => :min_low,
      "MaxLow"  => :max_low,
      "High"    => :default_high,
      "MinHigh" => :min_high,
      "MaxHigh" => :max_high,
      "Total"   => :total_memory
    }

    def initialize(configfile = nil)
      @configfile = configfile
      @kdumptool_executed = false
    end

    # Determines whether high memory support is available
    #
    # @return [Boolean] true if it's available; 'false' otherwise.
    def high_memory_supported?
      !max_high.zero?
    end

    # Determines what's the recommended quantity of low memory
    #
    # If high memory is not supported, this is the total recommended memory.
    #
    # @return [Fixnum] Memory size (in MiB)
    def default_low
      run_kdumptool unless @kdumptool_executed
      @default_low ||= min_low
    end

    # Determines what's the minimum quantity of low memory
    #
    # If high memory is not supported, this is the minimum kdump memory.
    #
    # @return [Fixnum] Memory size (in MiB)
    def min_low
      run_kdumptool unless @kdumptool_executed
      @min_low ||= MIN_LOW_DEFAULT
    end

    # Determines what's the recommended maximum quantity of low memory
    #
    # If high memory is not supported, this is the maximum recommended memory.
    #
    # @return [Fixnum] Memory size (in MiB)
    def max_low
      run_kdumptool unless @kdumptool_executed
      @max_low ||= propose_high_memory? ? [LOW_MEM, total_memory].min : total_memory
    end

    # Determines what's the recommended quantity of high memory
    #
    # @return [Fixnum] Memory size (in MiB)
    def default_high
      run_kdumptool unless @kdumptool_executed
      @default_high ||= min_high
    end

    # Determines what's the minimum quantity of high memory
    #
    # @return [Fixnum] Memory size (in MiB)
    def min_high
      run_kdumptool unless @kdumptool_executed
      @min_high ||= 0
    end

    # Determines what's the recommended maximum quantity of low memory
    #
    # If high memory is not supported, this is 0.
    #
    # @return [Fixnum] Memory size (in MiB)
    def max_high
      run_kdumptool unless @kdumptool_executed
      @max_high ||=
        if propose_high_memory?
          (total_memory - LOW_MEM) > 0 ? total_memory - LOW_MEM : 0
        else
          0
        end
    end

    # System available memory
    #
    # @return [Fixnum] Memory size (in MiB)
    def total_memory
      run_kdumptool unless @kdumptool_executed
      return @total_memory if @total_memory

      # Calculating the total memory in a system with kdump enabled is tricky.
      # As a best effort if kdumptool is not available, let's use the physical
      # memory reported by the kernel.
      probe = SCR.Read(Yast::Path.new(".probe.memory"))
      resource = probe.first["resource"]
      @total_memory = resource["phys_mem"][0]["range"] / MiB_SIZE
    end

    # Builds a hash containing memory limits
    #
    # It is just a convenience method to get a hash containing all limits.
    #
    # @return [Hash] Memory limits
    def memory_limits
      { min_low: min_low, max_low: max_low, min_high: min_high, max_high: max_high }
    end

  private

    # Set up memory values relying on kdumptool
    #
    # @see parse
    def run_kdumptool
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), kdumptool_cmd)
      if out["exit"].zero?
        proposal = parse(out["stdout"])
        # Populate @min_low, @max_low, @total_memory, etc.
        proposal.each_pair do |var_name, var_value|
          instance_variable_set("@#{var_name}", var_value)
        end
      else
        log.warn("kdumptool could not be executed: #{out["stderr"]}")
      end
      @kdumptool_executed = true
    end

    # Parses kdumptool output
    #
    # It supports new and old output formats of kdumptool.
    #
    # @return [Hash] Hash containing minimum and maximum low/high memory limits
    def parse(output)
      lines = output.split("\n")
      if lines.size == 1 # Old kdumptool version
        low = lines.first.to_i
        { min_low: low, default_low: low }
      else
        lines.each_with_object({}) do |line, prop|
          key, value = line.split(":").map(&:strip)
          prop[KEYS_MAP[key]] = value.to_i if KEYS_MAP.key?(key)
        end
      end
    end

    # Determines the kdumptool command line
    #
    # @return [String] kdumptool command line
    def kdumptool_cmd
      if @configfile
        args = KDUMPTOOL_ARG % @configfile
      else
        args = ""
      end
      KDUMPTOOL_CMD % args
    end

    # Checks whether the machine is expected to support high memory
    #
    # This method is only used in case the call to kdumptool failed
    #
    # @return [Boolean] true if a positive value for max_high is expected
    def propose_high_memory?
      Arch.x86_64
    end
  end
end
