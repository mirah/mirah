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

import com.google.appengine.tools.development.testing.LocalDatastoreServiceTestConfig
import com.google.appengine.tools.development.testing.LocalServiceTestConfig
import com.google.appengine.tools.development.testing.LocalServiceTestHelper

import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.Assert

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
import java.util.Date
import java.util.HashMap
import java.util.List
import java.util.ArrayList
import com.google.appengine.api.users.User

class TestModel < Model
  property 'date', Date
  property 'akey', Key
  property 'blob', Blob
  property 'shortblob', ShortBlob
  property 'category', Category
  property 'email', Email
  property 'geopt', GeoPt
  property 'imhandle', IMHandle
  property 'link', Link
  property 'phonenumber', PhoneNumber
  property 'address', PostalAddress
  property 'rating', Rating
  property 'text', Text
  property 'string', String
  property 'integer', Long
  property 'afloat', Double
  property 'user', User
  property 'list', List
end

class ModelTest
  include Assert

  def helper
    @helper ||= begin
      configs = LocalServiceTestConfig[1]
      configs[0] = LocalDatastoreServiceTestConfig.new
      LocalServiceTestHelper.new(configs)
    end
  end

  $Before
  def setup
    returns void
    helper.setUp
  end

  $After
  def teardown
    returns void
    helper.tearDown
  end

  $Test
  def test_get_and_put
    returns void
    e = TestModel.new
    e.string = "Hello"
    e.save
    e2 = TestModel.get(e.key)
    assertEquals("Hello", e2.string)
    assertEquals(e.key, e2.key)
  end

  $Test
  def test_sort
    returns void
    # just make sure it compiles
    TestModel.all.sort('link').run
  end

  $Test
  def test_properties
    returns void
    e = TestModel.new
    e.string = "Hi"
    e.rating = 10
    properties = e.properties
    assertEquals("Hi", properties.get("string"))
    assertEquals(Integer.valueOf(10), properties.get("rating"))
    assertTrue(properties.containsKey("blob"))
    assertEquals(nil, properties.get("blob"))
  end

  $Test
  def test_query_list
    returns void
    e = TestModel.new
    e.list = ["a", "b", "c"]
    e.save
    e2 = TestModel.all.list("b").first
    assertEquals(e.key, e2.key)
  end
  # TODO more tests.
end
