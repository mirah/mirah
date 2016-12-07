import duby.lang.compiler.*
import java.lang.ref.WeakReference
import java.util.Collections
import java.util.WeakHashMap

class DubyDatastorePlugin
  def initialize(mirah:Compiler)
    @mirah = WeakReference.new(mirah)
    @models = {}

    @type_map = {
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

    @primitives = ['Long', 'Double', 'Boolean', 'Rating']

    @boxes = {
      'int' => 'Integer',
      'boolean' => 'Boolean',
      'long' => 'Long',
      'double' => 'Double',
    }

    @defaults = {
      'Rating' => mirah.fixnum(0),
      'Long' => mirah.quote { long(0) },
      'Double' => mirah.quote { 0.0 },
      'Boolean' => mirah.quote { false },
      'Blob' => mirah.quote { byte[].cast(nil) },
      'ShortBlob' => mirah.quote { byte[].cast(nil) },
    }
  end

  def mirah:Compiler
    Compiler(@mirah.get)
  end

  def add_property(name_node:Node, type_node:Node, call:Call)
    parent = call.parent
    name = name_node.string_value
    ds_type = type_node.string_value
    ds_type = 'Long' if ds_type == 'Integer'

    # create an empty body
    result = Body(mirah.quote { nil; nil })

    klass = find_class(call.parent)
    model = find_model(klass, result)

    type_name = String(@type_map[ds_type]) || ds_type
    if type_name.endsWith('[]')
      array = true
      type_name = type_name.replace('[]', '')
    else
      array = false
      nil
    end
    coercion = "coerce_#{type_name.toLowerCase}#{array ? 's' : ''}"
    loader = "load_#{ds_type.toLowerCase}"
    duby_type = mirah.constant(type_name, array)

    name_string = mirah.string(name)
    update_query(model, name, ds_type, duby_type)
    model.read << mirah.quote do
      `name` = `'e'`.getProperty(`name_string`)
      @`name` = self.`loader`(`name`)
    end

    model.save << mirah.quote do
      e.setProperty(`name_string`, `to_datastore(ds_type, "@#{name}")`)
    end

    setter = "#{name}_set"
    model.update << mirah.quote do
      self.`setter`(properties.get(`name_string`)) if properties.containsKey(`name_string`)
    end

    value = maybe_box(type_name, mirah.quote {self.`name`})
    model.get_properties << mirah.quote do
      result.put(`name_string`, `value`)
    end

    result << mirah.quote do
      def `name`
        @`name`
      end

      def `setter`(value:`duby_type`)
        @`name` = value
      end

      def `setter`(value:Object)  #`
        @`name` = self.`coercion`(value)
      end
    end

    result
  end

  def find_class(node:Node):ClassDefinition
    while node && !node.kind_of?(ClassDefinition)
      node = node.parent
    end
    ClassDefinition(node)
  end

  def find_model(klass:ClassDefinition, ast:Body):ModelState
    unless @models[klass]
      @models[klass] = ModelState.new(mirah, klass, ast)
    end
    ModelState(@models[klass])
  end

  def to_datastore(type:String, value:Object):Object
    if @primitives.contains(type)
      Object(mirah.quote { `type`.new(`value`) })
    elsif @type_map.containsKey(type)
      Object(mirah.quote { (`value` ? `type`.new(`value`) : nil) })
    else
      value
    end
  end

  def maybe_box(duby_type:String, value:Object):Object
    if @boxes.containsKey(duby_type)
      Object(mirah.quote do
        `@boxes[duby_type]`.valueOf(`value`)
      end)
    else
      value
    end
  end

  # Generate the query filtering method for a property.
  def update_query(model:ModelState, property_name:String, type:String, duby_type:Node)
    name_node = mirah.string(property_name)
    if 'List'.equals type
      # We don't know what's in the list, so just use Object
      model.query << mirah.quote do
        def `property_name`(value:Object):void  #`
          _query.addFilter(`name_node`, FilterOperator.EQUAL, value)
        end
      end
    else
      model.query << mirah.quote do
        def `property_name`(value:`duby_type`):void  #`
          _query.addFilter(`name_node`,
                            FilterOperator.EQUAL,
                           `to_datastore(type, 'value')`)
        end
      end
    end
  end

  def self.initialize:void
    @@instances = Collections.synchronizedMap(WeakHashMap.new)
  end

  def self.get(mirah:Compiler)
    instance = @@instances[mirah]
    if (instance.nil?)
      instance = DubyDatastorePlugin.new(mirah)
      @@instances[mirah] = instance
    end
    DubyDatastorePlugin(instance)
  end
end

class ModelState
  macro def attr_reader(name)
    quote do
      def `name`  #`
        @`name`
      end
    end
  end
  attr_reader :kind
  attr_reader :query
  attr_reader :read
  attr_reader :save
  attr_reader :update
  attr_reader :get_properties

  def initialize(mirah:Compiler, klass:ClassDefinition, ast:Body)
    @mirah = WeakReference.new(mirah)
    path = klass.name.split('\\.')
    @kind = path[path.length - 1]
    init_query(klass.name)
    init_static(ast)

    # The nodes we add to ast will get dup'ed before being inserted, but
    # we need to be able to update some methods when add_property gets
    # called again.  So we insert these directly into the class definition.
    class_body = Body(klass.body)
    init_read(class_body)
    init_save(class_body)
  end

  def mirah:Compiler
    Compiler(@mirah.get)
  end

  def init_query(classname:String)
    name = "#{classname}$Query"
    superclass = 'com.google.appengine.ext.duby.db.DQuery'
    @query = Body(mirah.defineClass(name, superclass).body)
    array_size = mirah.quote { entities.size }
    @query << mirah.quote do
      import com.google.appengine.api.datastore.Entity
      import com.google.appengine.api.datastore.Query.FilterOperator

      def initialize; end

      def kind
        `mirah.string kind`
      end

      def first
        it = _prepare.asIterator
        if it.hasNext
          e = Entity(it.next)
          m = `kind`.new
          m._read_from(e)
          m
        else
          `mirah.cast(kind, mirah.quote {nil})`
        end
      end

      def run
        entities = _prepare.asList(_options)
        models = `mirah.empty_array(mirah.constant(kind), array_size)`
        it = entities.iterator
        i = 0
        while (it.hasNext)
          e = Entity(it.next)
          m = `kind`.new
          m._read_from(e)
          models[i] = m
          i += 1
        end
        models
      end
    end
  end

  def init_static(ast:Body)
    # # TODO These imports don't work any more.  Figure out how to fix that.
    # scope = ast.static_scope
    # package = "#{scope.package}." unless scope.package.empty?
    # scope.import('java.util.Map', 'Map')
    # scope.import("#{package}#{kind}$Query", "#{kind}__Query__")
    # %w( Entity Blob Category Email GeoPt IMHandle Key
    #     Link PhoneNumber PostalAddress Rating ShortBlob
    #     Text KeyFactory EntityNotFoundException ).each do |name|
    #   scope.import("com.google.appengine.api.datastore.#{name}", name)
    # end
    kind_string = mirah.string(kind)
    ast << mirah.quote do
      import com.google.appengine.api.datastore.Entity
      import com.google.appengine.api.datastore.EntityNotFoundException
      import com.google.appengine.api.datastore.Key
      import com.google.appengine.api.datastore.KeyFactory
      import com.google.appengine.ext.duby.db.Model
      import java.util.Map

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
          m = `kind`.new
          m._read_from(Model._datastore.get(key))
          m
        rescue EntityNotFoundException
          nil
        end
      end

      def self.get(key_name:String)
        get(KeyFactory.createKey(`kind_string`, key_name))
      end

      def self.get(id:long)
        get(KeyFactory.createKey(`kind_string`, id))
      end

      def self.get(parent:Key, key_name:String)
        get(KeyFactory.createKey(parent, `kind_string`, key_name))
      end

      def self.get(parent:Key, id:long)
        get(KeyFactory.createKey(parent, `kind_string`, id))
      end

      def self.get(parent:Model, key_name:String)
        get(KeyFactory.createKey(parent.key, `kind_string`, key_name))
      end

      def self.get(parent:Model, id:long)
        get(KeyFactory.createKey(parent.key, `kind_string`, id))
      end

      def self.all
        `kind`.Query.new
      end
    end
  end

  def init_read(ast:Body)
    # We're in the main class scope instead of the one we created earlier,
    # so we can't use our imports.
    entity = mirah.constant('com.google.appengine.api.datastore.Entity')
    map = mirah.constant('java.util.Map')
    mdef = mirah.quote do
      def _read_from(e:`entity`):void
        self.entity = e
        nil  # We need to statements to make sure we get a Body node.
      end
    end
    ast << mdef
    @read = Body(mdef.child_nodes.get(2))

    mdef = mirah.quote do
      def properties
        result = super()
        `mirah.body`
        result
      end
    end
    ast << mdef
    @get_properties = mdef.child_nodes.get(2).as!(Node).child_nodes.get(1).as!(Body)

    mdef = mirah.quote do
      def update(properties:`map`):void
        nil;nil
      end
    end
    ast << mdef
    @update = Body(mdef.child_nodes.get(2))
  end

  def init_save(ast:Body)
    entity = mirah.constant('com.google.appengine.api.datastore.Entity')
    mdef = mirah.quote do
      def _save_to(e:`entity`):void
        nil; nil
      end
    end
    ast << mdef
    @save = Body(mdef.child_nodes.get(2))
  end
end
