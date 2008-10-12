module Duby
  module JVM
    module MethodLookup
      def find_method(mapped_type, name, mapped_params, meta)
        if name == 'new'
          if meta
            name = "<init>"
            constructor = true
          else
            constructor = false
          end
        end

        begin
          if constructor
            method = mapped_type.constructor(*mapped_params)
          else
            method = mapped_type.java_method(name, *mapped_params)
          end
        rescue NameError
          unless constructor
            # exact args failed, do a deeper search
            log "Failed to locate method #{mapped_type}.#{name}(#{mapped_params})"

            if meta
              all_methods = mapped_type.declared_class_methods
            else
              all_methods = []
              cls = mapped_type
              while cls
                all_methods += cls.declared_instance_methods
                cls = cls.superclass
              end
            end
            by_name = all_methods.select {|m| m.name == name && mapped_params.size <= m.argument_types.size}
            by_name_and_arity = by_name.select {|m| m.argument_types.size == mapped_params.size}
            
            applicable_methods = phase1(mapped_params, by_name_and_arity)
            
            # dumb, pick first applicable after phase 1
            method = applicable_methods[0]
          end
          unless method
            log "Failed to locate method #{name}(#{mapped_params}) on #{mapped_type}"
            return nil
          end
        end

        log "Found method #{method.declaring_class}.#{name}(#{method.parameter_types}) from #{mapped_type}"
        return method
      end
        
      def phase1(mapped_params, by_name_and_arity)
        # TODO for now this just tries immediate supertypes, which
        # obviously wouldn't work on primitives; need to implement JLS
        # method selection here
        applicable_methods = []

        by_name_and_arity.each do |m|
          method_params = m.argument_types
          if each_is_exact_or_subtype(mapped_params, method_params)
            applicable_methods << m
          end
        end
      end
      
      def each_is_exact_or_subtype(incoming, target)
        incoming.each_with_index do |in_type, i|
          target_type = target[i]
          return false if target_type.primitive? || in_type.primitive? && target_type != in_type
          return false unless target_type.assignable_from? in_type
        end
        return true
      end
    end
  end
end