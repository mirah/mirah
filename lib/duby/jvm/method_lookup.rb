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
        by_name_and_arity.select do |m|
          method_params = m.argument_types
          each_is_exact_or_subtype_or_convertible(mapped_params, method_params)
        end
      end
      
      def each_is_exact_or_subtype_or_convertible(incoming, target)
        incoming.each_with_index do |in_type, i|
          target_type = target[i]
          
          # exact match
          next if target_type == in_type
          
          # primitive is safely convertible
          if target_type.primitive?
            if in_type.primitive?
              next if primitive_convertible? in_type, target_type
            end
            return false
          end
          
          # object type is assignable
          next if target_type.assignable_from? in_type
        end
        return true
      end
      
      BOOLEAN = Java::boolean.java_class
      BYTE = Java::byte.java_class
      SHORT = Java::short.java_class
      CHAR = Java::char.java_class
      INT = Java::int.java_class
      LONG = Java::long.java_class
      FLOAT = Java::float.java_class
      DOUBLE = Java::double.java_class
      
      PrimitiveConversions = {
        BOOLEAN => [BOOLEAN],
        BYTE => [BYTE, SHORT, CHAR, INT, LONG, FLOAT, DOUBLE],
        SHORT => [SHORT, INT, LONG, FLOAT, DOUBLE],
        CHAR => [CHAR, INT, LONG, FLOAT, DOUBLE],
        INT => [INT, LONG, FLOAT, DOUBLE],
        LONG => [LONG, DOUBLE],
        FLOAT => [FLOAT, DOUBLE],
        DOUBLE => [DOUBLE]
      }
      
      def primitive_convertible?(in_type, target_type)
        PrimitiveConversions[in_type].include?(target_type)
      end
    end
  end
end