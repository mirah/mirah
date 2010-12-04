module AppEngine
  class DubyDatastorePlugin
    @models = {}

    TypeMap = {
      'Category' => 'String',
      'Email' => 'String',
      'Link' => 'String',
      'PhoneNumber' => 'String',
      'PostalAddress' => 'String',
      'Text' => 'String',
      'Blob' => 'byte[]',
      'ShortBlob' => 'byte[]',
      'Rating' => 'int',
      'Long' => 'long',
      'Double' => 'double',
      'Boolean' => 'boolean'
    }

    Primitives = ['Long', 'Double', 'Boolean', 'Rating']

    Boxes = {
      'int' => 'Integer',
      'boolean' => 'Boolean',
      'long' => 'Long',
      'double' => 'Double',
    }

    Defaults = {
      'Rating' => '0',
      'Long' => 'long(0)',
      'Double' => '0.0',
      'Boolean' => 'false',
      'Blob' => 'byte[].cast(nil)',
      'ShortBlob' => 'byte[].cast(nil)',
    }

    Conversions = {
      'Category' => 'getCategory',
      'Email' => 'getEmail',
      'Link' => 'getValue',
      'PhoneNumber' => 'getNumber',
      'PostalAddress' => 'getAddress',
      'Text' => 'getValue',
      'Blob' => 'getBytes',
      'ShortBlob' => 'getBytes',
      'Long' => 'longValue',
      'Double' => 'doubleValue',
      'Boolean' => 'booleanValue',
      'Rating' => 'getRating',
    }

    class ModelState
      include Mirah::AST
      attr_reader :kind, :query, :read, :save, :transformer

      def initialize(transformer, klass, parent, position, ast)
        @transformer = transformer
        @kind = klass.name.split('.')[-1]
        init_query(klass.name, parent, position, ast)
        init_static(parent, ast)
        init_read(parent, position, ast)
        init_save(parent, position, ast)
      end

      def init_query(classname, parent, position, ast)
        name = "#{classname}$Query"
        @query = ClassDefinition.new(parent, position, name) do |classdef|
          queryinit = <<-EOF
            def initialize; end

            def kind
              "#{kind}"
            end

            def first
              it = _prepare.asIterator
              if it.hasNext
                e = Entity(it.next)
                m = #{kind}.new
                m._read_from(e)
                m
              else
                #{kind}(nil)
              end
            end

            def run
              entities = _prepare.asList(_options)
              models = #{kind}[entities.size]
              it = entities.iterator
              i = 0
              while (it.hasNext)
                e = Entity(it.next)
                m = #{kind}.new
                m._read_from(e)
                models[i] = m
                i += 1
              end
              models
            end

            def sort(name:String)
              sort(name, false)
            end

            def sort(name:String, descending:boolean)
              _sort(name, descending)
              self
            end
          EOF
          [Mirah::AST.type(nil, 'com.google.appengine.ext.duby.db.DQuery'),
           eval(classdef, queryinit)]
        end
        ast << @query
      end

      def init_read(parent, position, ast)
        @read = eval(parent, <<-EOF)
          def _read_from(e:Entity)
            self.entity = e
            nil
          end
        EOF
        ast << @read
        get_properties = eval(parent, <<-EOF)
          def properties
            result = super()
            nil
            result
          end
        EOF
        @get_properties = get_properties.body.children[1] =
            Mirah::AST::Body.new(get_properties.body, position)
        ast << get_properties
        update = eval(parent, <<-EOF)
          def update(properties:Map)
            nil
            self
          end
        EOF
        @update = update.body.children[0] = Body.new(update.body, position) {[]}
        ast << update
      end

      def init_save(parent, position, ast)
        @save = eval(parent, <<-EOF)
          def _save_to(e:Entity)
          end
        EOF
        @save.body = Body.new(@save, position) {[]}
        ast << @save
      end

      def init_static(parent, ast)
        # TODO These imports don't work any more.  Figure out how to fix that.
        scope = ast.static_scope
        package = "#{scope.package}." unless scope.package.empty?
        scope.import('java.util.Map', 'Map')
        scope.import("#{package}#{kind}$Query", "#{kind}__Query__")
        %w( Entity Blob Category Email GeoPt IMHandle Key
            Link PhoneNumber PostalAddress Rating ShortBlob
            Text KeyFactory EntityNotFoundException ).each do |name|
          scope.import("com.google.appengine.api.datastore.#{name}", name)
        end
        ast << eval(parent, <<-EOF)
          def initialize
            super
          end

          def initialize(key_name:String)
            super
          end
          
          def initialize(parent:Model)
            super
          end
          
          def initialize(parent:Key)
            super
          end
          
          def initialize(parent:Model, key_name:String)
            super
          end
          
          def initialize(parent:Key, key_name:String)
            super
          end

          def self.get(key:Key)
            begin
              m = #{kind}.new
              m._read_from(Model._datastore.get(key))
              m
            rescue EntityNotFoundException
              nil
            end
          end

          def self.get(key_name:String)
            get(KeyFactory.createKey("#{kind}", key_name))
          end

          def self.get(id:long)
            get(KeyFactory.createKey("#{kind}", id))
          end

          def self.get(parent:Key, key_name:String)
            get(KeyFactory.createKey(parent, "#{kind}", key_name))
          end

          def self.get(parent:Key, id:long)
            get(KeyFactory.createKey(parent, "#{kind}", id))
          end

          def self.get(parent:Model, key_name:String)
            get(KeyFactory.createKey(parent.key, "#{kind}", key_name))
          end

          def self.get(parent:Model, id:long)
            get(KeyFactory.createKey(parent.key, "#{kind}", id))
          end

          def self.all
            #{kind}__Query__.new
          end
        EOF
      end

      def eval(parent, src)
        transformer.eval(src, __FILE__, parent)
      end

      def extend_query(code)
        query.body << eval(query.body, code)
      end

      def extend_update(code)
        @update << eval(@update, code)
      end

      def extend_get_properties(code)
        @get_properties << eval(@get_properties, code)
      end

      def extend_read(code)
        code = 'e=nil;' + code
        eval(read.body, code).children[1..-1].each do |node|
          read.body << node
        end
      end

      def extend_save(code)
        code = 'e=nil;' + code
        eval(save.body, code).children[1..-1].each do |node|
          save.body << node
        end
      end
    end

    def self.find_class(node)
      node = node.parent until Mirah::AST::ClassDefinition === node
      node
    end

    def self.to_datastore(type, value)
      if Primitives.include?(type)
        "#{type}.new(#{value})"
      elsif TypeMap.include?(type)
        "(#{value} ? #{type}.new(#{value}) : nil)"
      else
        value
      end
    end

    def self.from_datastore(type, value)
      duby_type = TypeMap[type]
      if duby_type
        default = Defaults.fetch(type, "#{duby_type}(nil)")
        conversion = Conversions[type]
        "(#{value} ? #{type}(#{value}).#{conversion} : #{default})"
      else
        "#{type}(#{value})"
      end
    end


    def self.add_property(name, type, transformer, fcall)
      if transformer.state != @state
        reset
        @state = transformer.state
      end
      parent = fcall.parent
      name = name.literal
      type = type.name
      type = 'Long' if type == 'Integer'

      result = Mirah::AST::ScopedBody.new(parent, fcall.position) {[]}
      result.static_scope = fcall.scope.static_scope
      klass = find_class(parent)
      unless @models[klass]
        @models[klass] = ModelState.new(
            transformer, klass, parent, fcall.position, result)
      end
      model = @models[klass]

      duby_type = TypeMap.fetch(type, type)
      coercion = "coerce_" + duby_type.downcase.sub("[]", "s")

      if duby_type == 'List'
        model.extend_query(<<-EOF)
          def #{name}(value:Object)
            returns :void
            _query.addFilter("#{name}", _eq_op, value)
          end
        EOF
      else
        model.extend_query(<<-EOF)
          def #{name}(value:#{duby_type})
            returns :void
            _query.addFilter("#{name}", _eq_op, #{to_datastore(type, 'value')})
          end
        EOF
      end
      temp = transformer.tmp

      model.extend_read(<<-EOF)
        #{temp} = e.getProperty("#{name}")
        @#{name} = #{from_datastore(type, temp)}
      EOF

      model.extend_save(<<-EOF)
        e.setProperty("#{name}", #{to_datastore(type, '@' + name)})
      EOF

      model.extend_update(<<-EOF)
        self.#{name} = properties.get("#{name}") if properties.containsKey("#{name}")
      EOF

      model.extend_get_properties(<<-EOF)
        result.put("#{name}", #{maybe_box(duby_type, 'self.' + name)})
      EOF

      result << model.eval(parent, <<-EOF)
        def #{name}
          @#{name}
        end

        def #{name}=(value:#{duby_type})
          @#{name} = value
        end

        def #{name}=(value:Object)
          self.#{name} = #{coercion}(value)
        end
      EOF

      result
    end

    def self.maybe_box(duby_type, value)
      if Boxes.include?(duby_type)
        "#{Boxes[duby_type]}.valueOf(#{value})"
      else
        value
      end
    end

    def self.reset
      @models = {}
    end
  end
  ::Mirah.plugins << DubyDatastorePlugin
end
