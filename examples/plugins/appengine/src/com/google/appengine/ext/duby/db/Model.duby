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

import java.util.ConcurrentModificationException

import com.google.appengine.api.datastore.Blob
import com.google.appengine.api.datastore.Category
import com.google.appengine.api.datastore.DatastoreServiceFactory
import com.google.appengine.api.datastore.Email
import com.google.appengine.api.datastore.Entity
import com.google.appengine.api.datastore.EntityNotFoundException
import com.google.appengine.api.datastore.FetchOptions.Builder
import com.google.appengine.api.datastore.GeoPt
import com.google.appengine.api.datastore.IMHandle
import com.google.appengine.api.datastore.Key
import com.google.appengine.api.datastore.KeyFactory
import com.google.appengine.api.datastore.Link
import com.google.appengine.api.datastore.PhoneNumber
import com.google.appengine.api.datastore.PostalAddress
import com.google.appengine.api.datastore.Query
import com.google.appengine.api.datastore.Query.FilterOperator
import com.google.appengine.api.datastore.Query.SortDirection
import com.google.appengine.api.datastore.Rating
import com.google.appengine.api.datastore.ShortBlob
import com.google.appengine.api.datastore.Text
import com.google.appengine.api.users.User

import duby.lang.compiler.StringNode
import java.util.Arrays
import java.util.Date
import java.util.HashMap
import java.util.List
import java.util.Map

class DQuery
  def initialize
    @query = Query.new(kind)
  end

  def kind
    "foo"
  end

  def limit(l:int)
    returns void
    if @options
      @options.limit(l)
    else
      @options = Builder.withLimit(l)
    end
  end

  def offset(o:int)
    returns void
    if @options
      @options.offset(o)
    else
      @options = Builder.withOffset(o)
    end
  end

  def sort(name:String, descending=false):void
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
  macro def property(name, type)
    DubyDatastorePlugin.get(@mirah).add_property(name, type, @call)
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
    returns void
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
    returns void
    Model.delete(key)
  end

  def to_entity
    before_save
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

  def properties
    Map(HashMap.new)
  end

  def entity=(entity:Entity)
    @entity = entity
  end

  def parent
    @parent
  end

  def coerce_list(object:Object)
    if object.kind_of?(List)
      List(object)
    elsif object.kind_of?(Object[])
      Arrays.asList(Object[].cast(object))
    else
      raise IllegalArgumentException.new(
          "Expected List, got #{object} (#{object.getClass.getName})")
    end
  end

  def coerce_long(object:Object)
    if object.kind_of?(Number)
      Number(object).longValue
    elsif object.kind_of?(String)
      Long.parseLong(String(object))
    else
      raise IllegalArgumentException.new(
          "Expected Long, got #{object} (#{object.getClass.getName})")
    end
  end

  def coerce_int(object:Object)
    if object.kind_of?(Number)
      Number(object).intValue
    elsif object.kind_of?(String)
      Integer.parseInt(String(object))
    else
      raise IllegalArgumentException.new(
          "Expected Integer, got #{object} (#{object.getClass.getName})")
    end
  end

  def coerce_double(object:Object)
    if object.kind_of?(Number)
      Number(object).doubleValue
    elsif object.kind_of?(String)
      Double.parseDouble(String(object))
    else
      raise IllegalArgumentException.new(
          "Expected Double, got #{object} (#{object.getClass.getName})")
    end
  end

  def coerce_boolean(object:Object)
    if object.kind_of?(Boolean)
      Boolean(object).booleanValue
    elsif object.kind_of?(String)
      Boolean.parseBoolean(String(object))
    else
      raise IllegalArgumentException.new(
          "Expected Boolean, got #{object} (#{object.getClass.getName})")
    end
  end

  def coerce_date(object:Object)
    unless object.kind_of?(Date) || object.nil?
      raise IllegalArgumentException.new(
          "Expected Date, got #{object} (#{object.getClass.getName})")
    end
    Date(object)
  end

  def coerce_geopt(object:Object)
    unless object.kind_of?(GeoPt) || object.nil?
      raise IllegalArgumentException.new(
          "Expected GeoPt, got #{object} (#{object.getClass.getName})")
    end
    GeoPt(object)
  end

  def coerce_user(object:Object)
    unless object.kind_of?(User) || object.nil?
      raise IllegalArgumentException.new(
          "Expected User, got #{object} (#{object.getClass.getName})")
    end
    User(object)
  end

  def coerce_imhandle(object:Object)
    unless object.kind_of?(IMHandle) || object.nil?
      raise IllegalArgumentException.new(
          "Expected IMHandle, got #{object} (#{object.getClass.getName})")
    end
    IMHandle(object)
  end

  def coerce_string(object:Object)
    if object.nil?
      String(nil)
    else
      object.toString
    end
  end

  def coerce_key(object:Object)
    if object.kind_of?(Key) || object.nil?
      Key(object)
    elsif object.kind_of?(String)
      KeyFactory.stringToKey(String(object))
    else
      raise IllegalArgumentException.new(
          "Expected Key, got #{object} (#{object.getClass.getName})")
    end
  end

  def coerce_bytes(object:Object)
    if object.kind_of?(byte[]) || object.nil?
      byte[].cast(object)
    else
      raise IllegalArgumentException.new(
          "Expected byte[], got #{object} (#{object.getClass.getName})")
    end
  end

  # TODO coerce arrays to lists?

  macro def simple_loader(type_node)
    type = type_node.string_value
    name = "load_#{type.toLowerCase}"
    quote do
      def `name`(value:Object) #`
        `@mirah.cast(type, 'value')`
      end
    end
  end

  macro def converting_loader(from_node, converter)
    from = from_node.string_value
    name = "load_#{from.toLowerCase}"
    quote do
      def `name`(value:Object)  #`
        result = `@mirah.cast(from, 'value')`.`converter` if value
        result
      end
    end
  end

  simple_loader('Date')
  simple_loader('GeoPt')
  simple_loader('IMHandle')
  simple_loader('Key')
  simple_loader('List')
  simple_loader('String')
  simple_loader('User')
  converting_loader('Category', 'getCategory')
  converting_loader('Email', 'getEmail')
  converting_loader('Link', 'getValue')
  converting_loader('PhoneNumber', 'getNumber')
  converting_loader('PostalAddress', 'getAddress')
  converting_loader('Text', 'getValue')
  converting_loader('Blob', 'getBytes')
  converting_loader('ShortBlob', 'getBytes')
  converting_loader('Long', 'longValue')
  converting_loader('Double', 'doubleValue')
  converting_loader('Boolean', 'booleanValue')
  converting_loader('Rating', 'getRating')

  def before_save; end

  def self.transaction(block:Runnable):void
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
  def _save_to(e:Entity):void
  end

  def _read_from(e:Entity):void
  end
end
