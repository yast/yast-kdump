# encoding: utf-8

# File:
#      kdump_auto.ycp
#
# Module:
#      Kdump installation and configuration
#
# Summary:
#      Kdump autoinstallation preparation
#
# Authors:
#      Jozef Uhliarik <juhliarik@suse.cz>
#
#
module Yast
  class KdumpAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "kdump"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("kdump auto started")

      Yast.import "Kdump"
      Yast.import "Mode"
      Yast.import "Progress"

      Yast.include self, "kdump/wizards.rb"

      @progress_orig = Progress.set(false)

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Import"
        @ret = Kdump.Import(@param)
      # Create a summary
      # return string
      elsif @func == "Summary"
        @ret = Ops.add(
          Ops.add(
            "<UL>",
            Builtins.mergestring(Builtins.maplist(Kdump.Summary) do |l|
              Ops.add("<LI>", l)
            end, "\n")
          ),
          "</UL>"
        )
      # did configuration changed
      # return boolean
      elsif @func == "GetModified"
        @ret = Kdump.GetModified
      # set configuration as changed
      # return boolean
      elsif @func == "SetModified"
        Kdump.SetModified
        @ret = true
      # Reset configuration
      # return map or list
      elsif @func == "Reset"
        Kdump.Import({})
        @ret = {}
      # Change configuration
      # return symbol (i.e. `finish || `accept || `next || `cancel || `abort)
      elsif @func == "Change"
        @ret = KdumpAutoSequence()
        return deep_copy(@ret)
      # Return configuration data
      # return map or list
      elsif @func == "Export"
        @ret = Kdump.Export
      # Write configuration data
      # return boolean
      elsif @func == "Write"
        @ret = Kdump.Write
      elsif @func == "Read"
        @ret = Kdump.Read
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = false
      end
      Progress.set(@progress_orig)

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("kdump_auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)

      # EOF
    end
  end
end

Yast::KdumpAutoClient.new.main
