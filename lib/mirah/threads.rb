require 'jruby/synchronized'

module Duby
  module Threads
    class SynchronizedArray < Array
      include JRuby::Synchronized
    end

    class SynchronizedHash < Hash
      include JRuby::Synchronized
    end
  end
end