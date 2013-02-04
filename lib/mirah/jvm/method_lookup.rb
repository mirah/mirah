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
      java_import 'mirah.lang.ast.ConstructorDefinition'

      def find_method2(mapped_type, name, mapped_params, macro_params, meta, scope=nil, &block)
        find_method(mapped_type, name, mapped_params, macro_params, meta, scope, &block)
      rescue NameError => ex
        raise ex unless ex.message.include?(name)
        if block_given?
          block.call(ex)
        end
        ex
      end

      def find_method(mapped_type, name, mapped_params, macro_params, meta, scope=nil, &block)
        if mapped_type.error?
          raise "WTF?!?"
        end

        if name == 'new' && meta # we're calling SomeClass.new
          name = "<init>"
          constructor = true
          mapped_type = mapped_type.unmeta
          meta = false
        elsif name == 'new' && !meta # we're calling some_instance.new
          constructor = false
        elsif name == '<init>' && !meta # how do we get here?
          constructor = true
        elsif name == 'initialize' && !meta && scope
          context = scope.context
          if context.kind_of?(ConstructorDefinition) || context.findAncesor(ConstructorDefinition.class)
            constructor = true
            name = '<init>'
          end
        end

        if block_given?
          if constructor
            mapped_type.add_method_listener('initialize') {block.call(find_method2(mapped_type.meta, 'new', mapped_params, macro_params, true))}
          else
            mapped_type.add_method_listener(name) {block.call(find_method2(mapped_type, name, mapped_params, macro_params, meta))}
          end
          block.call(find_method(mapped_type, name, mapped_params, macro_params, meta))
          return
        end

        begin
          unless mapped_params.any? {|p| p.nil? || p.isError}
            if constructor
              method = mapped_type.constructor(*mapped_params)
            else
              method = mapped_type.java_method(name, *mapped_params)
            end
          end
        rescue NameError => ex
          # TODO return nil instead of raising an exception if the method doesn't exist.
          raise ex unless ex.message =~ /#{Regexp.quote(mapped_type.name)}\.#{Regexp.quote(name)}|No constructor #{Regexp.quote(mapped_type.name)}/
        end

        macro = mapped_type.macro(name, macro_params)
        if method && macro
          method = nil  # Need full lookup to determine precedence.
        elsif method.nil? && macro
          method = macro
        elsif method.nil?
          # exact args failed, do a deeper search
          log "No exact match for #{mapped_type.name}.#{name}(#{mapped_params.map(&:name).join ', '})" if mapped_params.all?

          method = find_jls(mapped_type, name, mapped_params, macro_params, meta, constructor, scope)

          unless method
            log "Failed to locate method #{mapped_type.name}.#{name}(#{mapped_params.map(&:name).join ', '})" if mapped_params.all?
            return nil
          end
        end

        log "Found method #{method.declaring_class.name}.#{name}(#{method.argument_types.map(&:name).join ', '}) from #{mapped_type.name}" if method
        return method
      end

      def find_jls(mapped_type, name, mapped_params, macro_params, meta, constructor, scope=nil)
        interfaces = []
        by_name = if constructor
          mapped_type.unmeta.declared_constructors
        elsif meta
          mapped_type.declared_class_methods(name)
        else
          mapped_type.find_callable_methods(name)
        end
        method = find_jls2(mapped_type, name, mapped_params, meta, by_name, true, scope)
        return method if (constructor || macro_params.nil?)
        macros = mapped_type.find_callable_macros(name)
        if macros.size != 0
          log "Found potential macro match for #{mapped_type.name}.#{name}(#{macro_params.map(&:full_name).join ', '})"
          macro = find_jls2(mapped_type, name, macro_params, meta, macros, false, scope)
        end
        if macro && method
          raise "Ambiguous targets invoking #{mapped_type}.#{name}:\n#{macro} and #{method}"
        end
        macro || method
      end

      def find_jls2(mapped_type, name, mapped_params, meta, by_name, include_fields=true, scope=nil)
        return nil if mapped_params.any? {|p| p.nil? || p.isError}

        # filter by arity, varargs
        by_name_and_arity = by_name.select {|m| m.argument_types.size == mapped_params.size }

        phase1_methods = phase1(mapped_params, by_name_and_arity)

        if phase1_methods.size > 1
          method_list = phase1_methods.map do |m|
            "#{m.name}(#{m.parameter_types.map(&:name).join(', ')})"
          end.join("\n")
          raise "Ambiguous targets invoking #{mapped_type}.#{name}:\n#{method_list}"
        end

        phase1_methods[0] ||
          phase2(mapped_params, by_name) ||
          phase3(mapped_params, by_name)[0] ||
          (include_fields &&
            (field_lookup(mapped_params, mapped_type, meta, name, scope) ||
             inner_class(mapped_params, mapped_type, meta, name)))
      end

      def phase1(mapped_params, potentials)
        log "Beginning JLS phase 1 search with params (#{mapped_params.map(&:name).join ', '})"

        # cycle through methods looking for more specific matches; gather matches of equal specificity
        methods = potentials.inject([]) do |currents, potential|
          method_params = potential.argument_types
          next currents unless method_params.all?

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
        potential_varargs = potentials.select{|m| m.varargs? }
        methods = potential_varargs.inject([]) do |currents, potential|
          method_params = potential.argument_types
          # match n-1 params of potential
          non_varargs_params, possible_varargs_params = mapped_params.partition.with_index{|param,i| i < method_params.size-1}
          
          vararg_types = possible_varargs_params.size.times.map{ method_params.last.component_type }
          
          if each_is_exact(non_varargs_params, method_params[0..-2]) &&
              each_is_exact(possible_varargs_params, vararg_types)
            return [potential]
          end
          
          if each_is_exact_or_subtype_or_convertible(non_varargs_params, method_params[0..-2]) &&
              each_is_exact_or_subtype_or_convertible(possible_varargs_params, vararg_types)
            currents << potential
          end

          currents
        end
      end

      def field_lookup(mapped_params, mapped_type, meta, name, scope)
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
          return nil
        end

        # check accessibility
        # TODO: protected field access check appropriate to current type
        if setter
          if field.final?
            log "cannot set final field '#{name}' on class #{mapped_type}"
            return nil
          end
        end
        unless field.public?
          from = " from #{scope.selfType.resolve.name}" if scope
          log "cannot access field '#{name}' on class #{mapped_type}#{from}"
          return nil
        end

        field
      end

      def inner_class(params, type, meta, name)
        return unless params.size == 0 && meta
        log("Attempting inner class lookup for '#{name}' on #{type}")
        type.inner_class_getter(name)
      end

      def each_is_exact(incoming, target)
        incoming.zip(target).all? { |in_type, target_type| target_type == in_type }
      end

      def each_is_exact_or_subtype_or_convertible(incoming, target)
        incoming.zip(target).each do |in_type, target_type|

          # exact match
          next if target_type == in_type

          unless target_type.respond_to?(:primitive?) && in_type.respond_to?(:primitive?)
            puts "Huh?"
          end
          # primitive is safely convertible
          if target_type.primitive?
            if in_type.primitive?
              next if primitive_convertible? in_type, target_type
            end
            return false
          end

          # object type is assignable
          compatible = if target_type.respond_to?(:compatible?)
            target_type.compatible? in_type
          else
            target_type.assignable_from? in_type
          end
          return false unless compatible
        end
        return true
      end

      def primitive_convertible?(in_type, target_type)
        in_type.convertible_to?(target_type)
      end
    end
  end
end
