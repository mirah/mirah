# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
# All contributing project authors may be found in the NOTICE file.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Mirah
  module JVM
    module MethodLookup
      # dummy log; it's expected the inclusion target will have it
      def log(msg); end

      def find_method(mapped_type, name, mapped_params, meta)
        raise ArgumentError if mapped_params.any? {|p| p.nil?}
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
          # exact args failed, do a deeper search
          log "No exact match for #{mapped_type.name}.#{name}(#{mapped_params.map(&:name).join ', '})"

          method = find_jls(mapped_type, name, mapped_params, meta, constructor)

          unless method
            log "Failed to locate method #{mapped_type.name}.#{name}(#{mapped_params.map(&:name).join ', '})"
            return nil
          end
        end

        log "Found method #{method.declaring_class.name}.#{name}(#{method.argument_types.map(&:name).join ', '}) from #{mapped_type.name}"
        return method
      end

      def find_jls(mapped_type, name, mapped_params, meta, constructor)
        interfaces = []
        if constructor
          by_name = mapped_type.unmeta.declared_constructors
        elsif meta
          by_name = mapped_type.declared_class_methods(name)
        else
          by_name = []
          cls = mapped_type
          while cls
            by_name += cls.declared_instance_methods(name)
            interfaces.concat(cls.interfaces)
            cls = cls.superclass
          end
          if mapped_type.interface?  # TODO or abstract
            seen = {}
            until interfaces.empty?
              interface = interfaces.pop
              next if seen[interface]
              seen[interface] = true
              interfaces.concat(interface.interfaces)
              by_name += interface.declared_instance_methods(name)
            end
          end
        end
        # filter by arity
        by_name_and_arity = by_name.select {|m| m.argument_types.size == mapped_params.size}

        phase1_methods = phase1(mapped_params, by_name_and_arity)

        if phase1_methods.size > 1
          method_list = phase1_methods.map do |m|
            
            "#{m.name}(#{m.parameter_types.map(&:name).join(', ')})"
          end.join("\n")
          raise "Ambiguous targets invoking #{mapped_type}.#{name}:\n#{method_list}"
        end

        phase1_methods[0] ||
          phase2(mapped_params, by_name) ||
          phase3(mapped_params, by_name) ||
          field_lookup(mapped_params, mapped_type, meta, name) ||
          inner_class(mapped_params, mapped_type, meta, name)
      end

      def phase1(mapped_params, potentials)
        log "Beginning JLS phase 1 search with params (#{mapped_params.map(&:name)})"

        # cycle through methods looking for more specific matches; gather matches of equal specificity
        methods = potentials.inject([]) do |currents, potential|
          method_params = potential.argument_types
          raise "Bad arguments for method #{potential.declaring_class}.#{potential.name}" unless method_params.all?

          # exact match always wins; duplicates not possible
          if each_is_exact(mapped_params, method_params)
            return [potential]
          end

          # otherwise, check for potential match and compare to current
          # TODO: missing ambiguity check; picks last method of equal specificity
          if each_is_exact_or_subtype_or_convertible(mapped_params, method_params)
            if currents.size > 0
              if is_more_specific?(potential.argument_types, currents[0].argument_types)
                # potential is better, dump all currents
                currents = [potential]
              elsif is_more_specific?(currents[0].argument_types, potential.argument_types)
                # currents are better, try next potential
                #next
              else
                # equal specificity, append to currents
                currents << potential
              end
            else
              # no previous matches, use potential
              currents = [potential]
            end
          end

          currents
        end

        methods
      end

      def is_more_specific?(potential, current)
        each_is_exact_or_subtype_or_convertible(potential, current)
      end

      def phase2(mapped_params, potentials)
        nil
      end

      def phase3(mapped_params, potentials)
        nil
      end

      def field_lookup(mapped_params, mapped_type, meta, name)
        log("Attempting #{meta ? 'static' : 'instance'} field lookup for '#{name}' on class #{mapped_type}")
        # if we get to this point, the potentials do not match, so we ignore them
        
        
        # search for a field of the given name
        if name =~ /_set$/
          # setter
          setter = true
          name = name[0..-5]
          field = mapped_type.field_setter(name)
        else
          # getter
          setter = false

          # field accesses don't take arguments
          return if mapped_params.size > 0
          field = mapped_type.field_getter(name)
        end

        return nil unless field

        if (meta && !field.static?) ||
            (!meta && field.static?)
          field == nil
        end

        # check accessibility
        # TODO: protected field access check appropriate to current type
        if setter
          raise "cannot set final field '#{name}' on class #{mapped_type}" if field.final?
        end
        raise "cannot access field '#{name}' on class #{mapped_type}" unless field.public?

        field
      end

      def inner_class(params, type, meta, name)
        return unless params.size == 0 && meta
        log("Attempting inner class lookup for '#{name}' on #{type}")
        type.inner_class_getter(name)
      end

      def each_is_exact(incoming, target)
        incoming.each_with_index do |in_type, i|
          target_type = target[i]

          # exact match
          return false unless target_type == in_type
        end
        return true
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
          return false unless target_type.compatible? in_type
        end
        return true
      end

      def primitive_convertible?(in_type, target_type)
        in_type.convertible_to?(target_type)
      end
    end
  end
end