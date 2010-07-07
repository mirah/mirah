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

    Primitives = ['Long', 'Double', 'Boolean']

    Defaults = {
      'Rating' => '0',
      'Long' => 'long(0)',
      'Double' => '0.0',
      'Boolean' => 'false'
    }

    Conversions = {
      'Category' => 'getCategory',
      'Email' => 'getEmail',
      'Link' => 'getValue',
      'PhoneNumber' => 'getNumber',
      'PostalAddress' => 'getAddress',
      'Text' => 'getValue',
      'Blob' => 'getBytes',
      'Long' => 'longValue',
      'Double' => 'doubleValue',
      'Boolean' => 'booleanValue',
    }

    class ModelState
      include Duby::AST
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
          EOF
          [Duby::AST.type('com.google.appengine.ext.duby.db.DQuery'),
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
        ast << eval(parent, <<-EOF)
          import com.google.appengine.api.datastore.Entity
          import com.google.appengine.api.datastore.Blob
          import com.google.appengine.api.datastore.Category
          import com.google.appengine.api.datastore.Email
          import com.google.appengine.api.datastore.GeoPt
          import com.google.appengine.api.datastore.IMHandle
          import com.google.appengine.api.datastore.Key
          import com.google.appengine.api.datastore.Link
          import com.google.appengine.api.datastore.PhoneNumber
          import com.google.appengine.api.datastore.PostalAddress
          import com.google.appengine.api.datastore.Rating
          import com.google.appengine.api.datastore.ShortBlob
          import com.google.appengine.api.datastore.Text
          import com.google.appengine.api.datastore.KeyFactory
          import com.google.appengine.api.datastore.EntityNotFoundException
          import '#{kind}__Query__', '#{kind}$Query'

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

          def self.get(parent:Key, key_name:String)
            get(KeyFactory.createKey(parent, "#{kind}", key_name))
          end

          def self.get(parent:Model, key_name:String)
            get(KeyFactory.createKey(parent.key, "#{kind}", key_name))
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
      node = node.parent until Duby::AST::ClassDefinition === node
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
      parent = fcall.parent
      name = name.literal
      type = type.name
      type = 'Long' if type == 'Integer'

      result = Duby::AST::Body.new(parent, fcall.position) {[]}
      klass = find_class(parent)
      unless @models[klass]
        @models[klass] = ModelState.new(
            transformer, klass, parent, fcall.position, result)
      end
      model = @models[klass]

      duby_type = TypeMap.fetch(type, type)

      model.extend_query(<<-EOF)
        def #{name}(value:#{duby_type})
          returns :void
          _query.addFilter("#{name}", _eq_op, #{to_datastore(type, 'value')})
        end
      EOF

      temp = transformer.tmp

      model.extend_read(<<-EOF)
        #{temp} = e.getProperty("#{name}")
        @#{name} = #{from_datastore(type, temp)}
      EOF

      model.extend_save(<<-EOF)
        e.setProperty("#{name}", #{to_datastore(type, '@' + name)})
      EOF

      result << model.eval(parent, <<-EOF)
        def #{name}
          @#{name}
        end

        def #{name}=(value:#{duby_type})
          @#{name} = value
        end
      EOF

      result
    end

    def self.reset
      @models = {}
    end
  end
  ::Duby.plugins << DubyDatastorePlugin
end
