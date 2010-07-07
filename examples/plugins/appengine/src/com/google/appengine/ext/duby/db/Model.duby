import java.util.ConcurrentModificationException

import com.google.appengine.api.datastore.DatastoreServiceFactory
import com.google.appengine.api.datastore.Entity
import com.google.appengine.api.datastore.EntityNotFoundException
import com.google.appengine.api.datastore.Key
import com.google.appengine.api.datastore.KeyFactory
import com.google.appengine.api.datastore.Query
import 'Builder', 'com.google.appengine.api.datastore.FetchOptions$Builder'
import 'FilterOperator', 'com.google.appengine.api.datastore.Query$FilterOperator'
import 'SortDirection', 'com.google.appengine.api.datastore.Query$SortDirection'

class DQuery
  def initialize
    @query = Query.new(kind)
  end

  def kind
    "foo"
  end

  def limit(l:int)
    returns :void
    if @options
      @options.limit(l)
    else
      @options = Builder.withLimit(l)
    end
  end

  def offset(o:int)
    returns :void
    if @options
      @options.offset(o)
    else
      @options = Builder.withOffset(o)
    end
  end

  def sort(name:String)
    sort(name, false)
  end

  def sort(name:String, descending:boolean)
    returns :void
    if descending
      @query.addSort(name, _desc)
    else
      @query.addSort(name)
    end
  end

  def count
    _prepare.countEntities
  end

  def _query
    @query
  end

  def _options
    if @options.nil?
      @options = Builder.withOffset(0)
    end
    @options
  end

  def _prepare
    Model._datastore.prepare(@query)
  end

  def _eq_op
    FilterOperator.valueOf("EQUAL")
  end

  def _desc
    SortDirection.valueOf("DESCENDING")
  end
end

class Model
  defmacro property(name, type) do
    # This is a hack to make packaging possible.
    # Everything's still written in ruby, but we load it out of
    # the datastore plugin's JAR. So as long as Model is in your CLASSPATH
    # you don't need any extra arguments to dubyc.
    code = <<RUBY
      require 'com/google/appengine/ext/duby/db/datastore.rb'
      AppEngine::DubyDatastorePlugin.add_property(*arg.to_a)
RUBY
    @duby.__ruby_eval(code, [name, type, @duby, @call])
  end

  def initialize; end

  def initialize(key_name:String)
    @key_name = key_name
  end

  def initialize(parent:Model)
    @parent = parent.key
  end

  def initialize(parent:Key)
    @parent = parent
  end

  def initialize(parent:Model, key_name:String)
    @parent = parent.key
    @key_name = key_name
  end

  def initialize(parent:Key, key_name:String)
    @parent = parent
    @key_name = key_name
  end

  def self._datastore
    unless @service
      @service = DatastoreServiceFactory.getDatastoreService
    end
    @service
  end

  def self.delete(key:Key)
    returns :void
    keys = Key[1]
    keys[0] = key
    Model._datastore.delete(keys)
  end

  def kind
    getClass.getSimpleName
  end

  def key
    if @entity
      @entity.getKey
    elsif @key_name
      if @parent
        KeyFactory.createKey(@parent, kind, @key_name)
      else
        KeyFactory.createKey(kind, @key_name)
      end
    else
      Key(nil)
    end
  end

  def save
    Model._datastore.put(to_entity)
  end

  def delete
    returns :void
    Model.delete(key)
  end

  def to_entity
    @entity ||= begin
      if @key_name
        Entity.new(key)
      elsif @parent
        Entity.new(kind, @parent)
      else
        Entity.new(kind)
      end
    end
    _save_to(@entity)
    @entity
  end

  def entity=(entity:Entity)
    @entity = entity
  end

  def parent
    @parent
  end

  def self.transaction(block:Runnable)
    returns :void
    tries = 3
    while tries > 0
      begin
        tries -= 1
        tx = Model._datastore.beginTransaction
        begin
          block.run
          tx.commit
          return
        ensure
          tx.rollback if tx.isActive
        end
      rescue ConcurrentModificationException => ex
        unless tries > 0
          raise ex
        end
      end
    end
  end

  # protected
  def _save_to(e:Entity)
  end

  def _read_from(e:Entity)
  end
end