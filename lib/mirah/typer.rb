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

require 'mirah/ast'
require 'mirah/transform'
require 'mirah/errors'

module Mirah
  module Typer
    class << self
      attr_accessor :verbose

      def log(message)
        puts "* [#{name}] #{message}" if Typer.verbose
      end
    end

    InferenceError = Mirah::InferenceError

    class BaseTyper
      include Mirah

      def log(message); Typer.log(message); end

      def to_s
        name
      end
    end

    class Simple < BaseTyper
      attr_accessor :known_types, :errors, :last_chance

      def initialize(self_type)
        @known_types = {}

        @known_types["self"] = type_reference(nil, self_type)
        @known_types["fixnum"] = type_reference(nil, "fixnum")
        @known_types["float"] = type_reference(nil, "float")
        @known_types["string"] = type_reference(nil, "string")
        @known_types["boolean"] = type_reference(nil, "boolean")
        @errors = []
      end

      def name
        "Simple"
      end

      def set_filename(scope, name); end

      def self_type
        known_types["self"]
      end

      def default_type
        nil
      end

      def fixnum_type(value=0)
        known_types["fixnum"]
      end

      def float_type(value=0)
        known_types["float"]
      end

      def string_type
        known_types["string"]
      end

      def boolean_type
        known_types["boolean"]
      end

      def null_type
        AST::TypeReference::NullType
      end

      def no_type
        AST::TypeReference::NoType
      end

      # to be overridden
      def array_type
        AST::TypeReference::NullType
      end

      # to be overridden
      def hash_type
        AST::TypeReference::NullType
      end

      def known_type(scope, name)
        @known_types[name]
      end

      def define_type(scope, name, superclass, interfaces)
        log "New type defined: '#{name}' < '#{superclass}'"
        result = type_definition(scope, name, superclass, interfaces)

        # TODO Get rid of known_types["self"]
        old_self, known_types["self"] = known_types["self"], result
        yield
        known_types["self"] = old_self

        result
      end

      def learn_local_type(scope, name, type)
        type = scope.learn_local_type(name, known_types[type] || type)
        log "Learned local type under #{scope} : #{name} = #{type}"
        type
      end

      def local_type(scope, name)
        type = scope.local_type(name)
        log "Retrieved local type in #{scope} : #{name} = #{type}" if type
        type
      end

      def local_types
        @local_types ||= {}
      end

      def local_type_hash(scope)
        local_types[scope] ||= {}
      end

      def field_types
        @field_types ||= {}
      end

      def field_type_hash(cls)
        field_types[cls] ||= {}
      end

      def static_field_types
        @static_field_types ||= {}
      end

      def static_field_type_hash(cls)
        static_field_types[cls] ||= {}
      end
      
      def infer_signature(method_def)
      end

      def learn_field_type(cls, name, type)
        log "Learned field type under #{cls} : #{name} = #{type}"

        # TODO check for compatibility?
        field_type_hash(cls)[name] ||= known_types[type] || type

        type
      end

      def field_type(cls, name)
        field_type_hash(cls)[name]
      end

      def learn_static_field_type(cls, name, type)
        log "Learned field type under #{cls} : #{name} = #{type}"

        # TODO check for compatibility?
        static_field_type_hash(cls)[name] ||= known_types[type] || type

        type
      end

      def static_field_type(cls, name)
        static_field_type_hash(cls)[name]
      end

      def learn_method_type(target_type, name, parameter_types, type, exceptions)
        log "Learned method #{name} (#{parameter_types}) on #{target_type} = #{type}"

        get_method_type_hash(target_type, name, parameter_types)[:type] = known_types[type] || type

        # if it's any args are imported types, also add a mapping for the expanded name
        imported_types = parameter_types.map {|param| known_types[param] || param}
        get_method_type_hash(target_type, name, imported_types)[:type] = type
      end

      def method_type(target_type, name, parameter_types)
        if (target_type && target_type.error?) ||
            parameter_types.any? {|t| t && t.error?}
          return AST.error_type
        end
        constructor = (name == 'new' && target_type && target_type.meta?)

        if constructor
          # constructor handled different from other methods
          simple_type = get_method_type_hash(target_type.unmeta, 'initialize', parameter_types)[:type]
        else
          simple_type = get_method_type_hash(target_type, name, parameter_types)[:type]
        end


        if !simple_type
          log "Method type for \"#{name}\" #{parameter_types} on #{target_type} not found."

          # allow plugins a go if we're in the inference phase
          simple_type = plugins do |plugin|
            plugin.method_type(self, target_type, name, parameter_types)
          end
        end

        return nil unless simple_type

        if constructor
          log "Method type for \"#{name}\" #{parameter_types} on #{target_type} = #{target_type}"
          target_type.unmeta
        else
          log "Method type for \"#{name}\" #{parameter_types} on #{target_type} = #{simple_type}"
          simple_type
        end
      end

      def plugins
        if cycling?
          Mirah.typer_plugins.each do |plugin|
            log "Invoking plugin: #{plugin}"

            result = yield plugin
            return result if result
          end
        end

        nil
      end

      def cycling?
        @cycling
      end

      def cycling=(c)
        @cycling = c
      end

      def cycle(count)
        @cycling = true
        count.times do |i|
          begin
            log "[Cycle #{i}]: Started..."
            yield i
          ensure
            log "[Cycle #{i}]: Complete!"
          end
        end
      ensure
        @cycling = false
      end

      def method_types
        @method_types ||= {}
      end

      def get_method_type_hash(target_type, name, parameter_types)
        method_types[target_type] ||= {}
        method_types[target_type][name] ||= {}
        method_types[target_type][name][parameter_types.size] ||= {}

        current = method_types[target_type][name][parameter_types.size]

        parameter_types.each {|type| current[type] ||= {}; current = current[type]}

        current
      end

      def type_reference(scope, name, array=false, meta=false)
        AST::TypeReference.new(name, array, meta)
      end

      def type_definition(scope, name, superclass, interfaces)
        AST::TypeDefinition.new(name, AST::TypeReference.new(superclass), interfaces)
      end

      def deferred_nodes
        @deferred_nodes ||= {}
      end

      def infer(node, expression=true)
        begin
          node.infer(self, expression)
        rescue InferenceError => ex
          ex.node ||= node
          error(node, ex)
        rescue Exception => ex
          raise Mirah::InternalCompilerError.wrap(ex, node)
        end
      end

      def error(node, error_or_msg=nil, backtrace=nil)
        if error_or_msg.kind_of? InferenceError
          error = error_or_msg
        elsif error_or_msg
          error = InferenceError.new(error_or_msg, node)
          error.set_backtrace(backtrace) if backtrace
        else
          error = InferenceError.new("Unable to infer type.", node)
        end
        @errors << error
        node.resolve_if(self) do
          AST.error_type
        end
      end

      def defer(node, error_message=nil)
        if @error_next
          log "Marking #{node} as an error"
          @error_next = false
          error(node, error_message)
        else
          raise "Can't defer nil" if node.nil?
          return if deferred_nodes.include? node
          log "Deferring inference for #{node}"

          deferred_nodes[node] = self_type
        end
      end

      def resolve(raise = false)
        count = deferred_nodes.size + 1

        log "Entering type inference cycle"

        retried = false
        cycle(count) do |i|
          old_deferred = @deferred_nodes
          @deferred_nodes = {}
          old_deferred.each do |node, saved_type|
            known_types["self"] = saved_type
            type = infer(node)

            log "[Cycle #{i}]: Inferred type for #{node}: #{type || 'FAILED'}"

            if type == default_type
              @deferred_nodes[node] = saved_type
            end
          end

          if @deferred_nodes.size == 0
            log "[Cycle #{i}]:  Resolved all types, exiting"
            break
          elsif old_deferred == @deferred_nodes
            if @error_next || retried
              log "[Cycle #{i}]: Made no progress, bailing out"
              break
            elsif @last_chance
              # Retry this iteration, and mark the first deferred
              # type as an error.
              retried = true
              @error_next = true
              redo
            else
              # This is a hack for default constructor support.  The right fix
              # is probably to check the AST for constructors. Instead we
              # tell the plugins that we're near the end of inference so they
              # can assume no new constructors are being added.  You could
              # easily write some circular constructors that would compile
              # with this technique but fail to run.
              @last_chance = true
              redo
            end
          end
          retried = false
        end

        # done with n sweeps, if any remain mark them as errors
        error_nodes = @errors.map {|e| e.node}
        (deferred_nodes.keys - error_nodes).each do |deferred_node|
          error_nodes << deferred_node
          error(deferred_node)
        end
        if raise && !error_nodes.empty?
          msg = "Could not infer typing for nodes:"
          error_nodes.map do |e|
            msg << "\n  "
            msg << "#{e.inspect} at line #{e.line_number} (child of #{e.parent})"
          end
          raise InferenceError.new(msg)
        end
      end
    end
  end

  def self.typer_plugins
    @typer_plugins ||= []
  end
end

if __FILE__ == $0
  Mirah::AST.verbose = true
  Mirah::Typer.verbose = true
  ast = Mirah::AST.parse(File.read(ARGV[0]))
  typer = Mirah::Typer::Simple.new("script")
  typer.infer(ast)
  begin
    typer.resolve(true)
  rescue Mirah::Typer::InferenceError => e
    puts e.message
  end

  puts "\nAST:"
  p ast
end