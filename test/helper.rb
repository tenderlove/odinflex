ENV["MT_NO_PLUGINS"] = "1"

require "minitest/autorun"
require "odinflex/mach-o"
require "odinflex/ar"
require "rbconfig"
require "fiddle"

module OdinFlex
  class Test < Minitest::Test
    def ruby_archive
      File.join RbConfig::CONFIG["prefix"], "lib", RbConfig::CONFIG["LIBRUBY_A"]
    end

    def ruby_so
      File.join RbConfig::CONFIG["prefix"], "lib", RbConfig::CONFIG["LIBRUBY"]
    end
  end
end
