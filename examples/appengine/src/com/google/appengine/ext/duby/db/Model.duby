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
  def initialize
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
    unless @entity
      @entity = Entity.new(kind)
    end
    _save_to(@entity)
    @entity
  end
  
  # protected
  def _save_to(e:Entity)
  end
  
  def _read_from(e:Entity)
  end
end