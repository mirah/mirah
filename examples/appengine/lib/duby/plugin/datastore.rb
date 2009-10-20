class DatastorePlugin
  @models = {}
  
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
      ast.children << @query
    end
    
    def init_read(parent, position, ast)
      @read = eval(parent, <<-EOF)
        def _read_from(e:Entity)
        end
      EOF
      @read.body = @read.children[2] = Body.new(@read, position) {[]}
      ast.children << @read
    end
    
    def init_save(parent, position, ast)
      @save = eval(parent, <<-EOF)
        def _save_to(e:Entity)
        end
      EOF
      @save.body = @save.children[2] = Body.new(@save, position) {[]}
      ast.children << @save
    end
    
    def init_static(parent, ast)
      ast.children << eval(parent, <<-EOF)
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
        import '#{kind}__Query__', '#{kind}$Query'

        def self.get(key:Key)
          m = #{kind}.new
          m._read_from(Model._datastore.get(key))
          m
        end
        
        def self.all
          #{kind}__Query__.new
        end
      EOF
    end

    def eval(parent, src)
      ast = Duby::AST.parse_ruby(src, __FILE__)
      transformer.transform(ast.body_node, parent)
    end

    def extend_query(code)
      query.body.children << eval(query.body, code)
    end

    def extend_read(code)
      code = 'e=nil;' + code
      read.body.children.concat eval(read.body, code).children[1..-1]
    end
    
    def extend_save(code)
      code = 'e=nil;' + code
      save.body.children.concat eval(save.body, code).children[1..-1]
    end
  end
  
  def self.find_class(node)
    node = node.parent until Duby::AST::ClassDefinition === node
    node
  end
  
  Duby::AST.defmacro("property") do |transformer, fcall, parent|
    result = Duby::AST::Body.new(parent, fcall.position) {[]}
    klass = find_class(parent)
    unless @models[klass]
      @models[klass] = ModelState.new(
          transformer, klass, parent, fcall.position, result)
    end
    model = @models[klass]

    name = fcall.args_node.get(0).name
    type = fcall.args_node.get(1).name

    model.extend_query(<<-EOF)
      def #{name}(value:#{type})
        returns :void
        _query.addFilter("#{name}", _eq_op, value)
      end
    EOF
    
    model.extend_read(<<-EOF)
      @#{name} = #{type}(e.getProperty("#{name}"))
    EOF
    
    model.extend_save(<<-EOF)
      e.setProperty("#{name}", @#{name})
    EOF
    
    result.children << model.eval(parent, <<-EOF)
      def #{name}
        @#{name}
      end
      
      def #{name}=(value:#{type})
        @#{name} = value
      end
    EOF

    result
  end
end