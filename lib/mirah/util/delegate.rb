# Ripped from 1.8 stdlib

module Mirah
  module Util
    class Delegator
      IgnoreBacktracePat = %r"\A#{Regexp.quote(__FILE__)}:\d+:in `"
    end
  
    def self.DelegateClass(superclass)
      klass = Class.new
      methods = superclass.public_instance_methods(true).map(&:to_s)
      methods -= ::Kernel.public_instance_methods(false).map(&:to_s)
      methods -= ["__id__", "__send__"] if RUBY_VERSION > '1.9' # avoid warnings
      methods |= ["to_s","to_a","inspect","==","=~","==="]
      klass.module_eval {
        def initialize(obj)  # :nodoc:
          @_dc_obj = obj
        end
        def method_missing(m, *args)  # :nodoc:
          unless @_dc_obj.respond_to?(m)
            super(m, *args)
          end
          @_dc_obj.__send__(m, *args)
        end
        def respond_to?(m, include_private = false)  # :nodoc:
          return true if super
          return @_dc_obj.respond_to?(m, include_private)
        end
        def __getobj__  # :nodoc:
          @_dc_obj
        end
        def __setobj__(obj)  # :nodoc:
          raise ArgumentError, "cannot delegate to self" if self.equal?(obj)
          @_dc_obj = obj
        end
        def clone  # :nodoc:
          new = super
          new.__setobj__(__getobj__.clone)
          new
        end
        def dup  # :nodoc:
          new = super
          new.__setobj__(__getobj__.clone)
          new
        end
      }
      for method in methods
        begin
          klass.module_eval <<-EOS, __FILE__, __LINE__+1
            def #{method}(*args, &block)
            	  begin
            	    @_dc_obj.__send__(:#{method}, *args, &block)
            	  ensure
            	    $@.delete_if{|s| ::Mirah::Util::Delegator::IgnoreBacktracePat =~ s} if $@
            	  end
            	end
          EOS
        rescue SyntaxError
          raise NameError, "invalid identifier %s" % method, caller(3)
        end
      end
      return klass
    end
  end
end