# encoding: utf-8

# File:
#  kdump_finish.ycp
#
# Module:
#  Step of base installation finish
#
# Authors:
#  Jozef Uhliarik <juhliarik@suse.cz>
#
#
module Yast
  class KdumpFinishClient < Client
    def main

      textdomain "kdump"

      Yast.import "Kdump"
      Yast.import "Mode"
      Yast.import "Progress"

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

      @progress_orig = Progress.set(false)

      Builtins.y2milestone("starting kdump_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 3,
          # progress step title
          "title" => _("Saving kdump configuration..."),
          "when"  => [:installation, :update, :autoinst]
        }
      elsif @func == "Write"
        # propose settings for kdump if autoyast doesn't include settings for yast2-kdump
        Kdump.Propose if !Kdump.import_called && Mode.autoinst
        if Mode.update
          Kdump.Update
        else
          Kdump.Write
        end
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end
      Progress.set(@progress_orig)
      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("kdump_finish finished")
      deep_copy(@ret)
    end
  end
end

Yast::KdumpFinishClient.new.main
