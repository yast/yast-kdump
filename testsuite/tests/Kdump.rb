# encoding: utf-8

module Yast
  class KdumpClient < Client
    def main
      # testedfiles: Kdump.ycp

      Yast.include self, "testsuite.rb" 
      # map I_READ = $[];
      # map I_WRITE = $[];
      # map I_EXEC = $[
      # 	"target" : $[
      # 	    "bash_output" : $[],
      # 	],
      #     ];
      #
      # TESTSUITE_INIT([I_EXEC, I_READ, I_WRITE], nil);
      #
      #
      # import "Kdump";
      #
      #
      # DUMP("Kdump::Modified");
      # TEST(``(Kdump::Modified()), [], nil);

      nil
    end
  end
end

Yast::KdumpClient.new.main
