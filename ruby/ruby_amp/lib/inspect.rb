require RubyAMP.lib_root + "/ruby_tm_helpers"

module RubyAMP
  module Inspect
    def self.get_selection
      tm_expanded_selection(
        :forward => /[a-z0-9_]*[\?\!]{0,1}/i,
        :backward => /[a-z0-9._:]*[@$]*/i
      )
    end
  end
end
  
