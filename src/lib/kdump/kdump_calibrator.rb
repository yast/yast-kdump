module Yast
  # This class tries to calibrate Kdump minimum and maximum values
  #
  # It relies on kdumptool but, if the tool is not available or does not work
  # as expected, tries to set up reasonable memory values on its own.
  class KdumpCalibrator
    include Yast::Logger

    LOW_MEM = 896
    MIN_LOW_DEFAULT = 72
    MB_SIZE = 1048576

    KDUMPTOOL_CMD = "kdumptool --configfile '%1' calibrate"
    KEYS_MAP = {
      "MinLow" => :min_low,
      "MaxLow" => :max_low,
      "MinHigh" => :min_high,
      "MaxHigh" => :max_high
    }

    def initialize(configfile)
      @configfile = configfile
      setup
    end

    # Determines whether high memory support is available
    #
    # @return [Boolean] true if it's available; 'false' otherwise.
    def high_memory_supported?
      Arch.x86_64
    end

    # Determines what's the recommended minimum quantity of low memory
    #
    # If high memory is not supported, this is the minimum recommended memory.
    #
    # @return [Fixnum] Memory size (in MB)
    def min_low
      @min_low ||= MIN_LOW_DEFAULT
    end

    # Determines what's the recommended maximum quantity of low memory
    #
    # If high memory is not supported, this is the maximum recommended memory.
    #
    # @return [Fixnum] Memory size (in MB)
    def max_low
      @max_low ||= high_memory_supported? ? [LOW_MEM, total_memory].min : total_memory
    end

    # Determines what's the recommended maximum quantity of high memory
    #
    # If high memory is not supported, this is 0.
    #
    # @return [Fixnum] Memory size (in MB)
    def min_high
      @min_high ||= 0
    end

    # Determines what's the recommended maximum quantity of low memory
    #
    # If high memory is not supported, this is 0.
    #
    # @return [Fixnum] Memory size (in MB)
    def max_high
      @max_high ||=
        if high_memory_supported?
          (total_memory - LOW_MEM) > 0 ? total_memory - LOW_MEM : 0
        else
          0
        end
    end

    # System available memory
    #
    # @return [Fixnum] Memory size (in MB)
    def total_memory
      probe = SCR.Read(Yast::Path.new(".probe.memory"))
      resource = probe.first["resource"]
      resource["phys_mem"][0]["range"] / MB_SIZE
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
    def setup
      out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), kdumptool_cmd)
      if out["exit"].zero?
        proposal = parse(out["stdout"])
        @min_low = proposal[:min_low]
        @max_low = proposal[:max_low]
        if high_memory_supported?
          @min_high = proposal[:min_high]
          @max_high = proposal[:max_high]
        end
      else
        log.warn("kdumptool could not be executed: #{out["stderr"]}")
      end
    end

    # Parses kdumptool output
    #
    # It supports new and old memories of kdumptool.
    #
    # @return [Hash] Hash containing minimum and maximum low/high memory limits
    def parse(output)
      lines = output.split("\n")
      if lines.size == 1 # Old kdumptool version
        { min_low: value.to_i }
      else
        lines.each_with_object({}) do |line, prop|
          key, value = line.split(":").map(&:strip)
          prop[KEYS_MAP[key]] = value.to_i if KEYS_MAP.has_key?(key)
        end
      end
    end

    # Determines the kdumptool command line
    #
    # @return [String] kdumptool command line
    def kdumptool_cmd
      Builtins.sformat(KDUMPTOOL_CMD, @configfile)
    end
  end
end
