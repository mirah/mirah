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

require 'delegate'

module Mirah::JVM::Types
  class ExtendedType < DelegateClass(Type)
    def initialize(*args)
      super
      @static_includes = []
    end

    def include(type)
      @static_includes << type
      self
    end

    def meta
      if meta?
        self
      else
        __getobj__.meta
      end
    end

    def unmeta
      if meta?
        __getobj__.unmeta
      else
        self
      end
    end

    def get_method(name, args)
      method = __getobj__.get_method(name, args)
      return method if method
      @static_includes.each do |type|
        method = type.meta.get_method(name, args)
        return method if method
      end
      nil
    end

    def java_method(name, *types)
      __getobj__.java_method(name, *types) || __included_method(name, types)
    end

    def java_static_method(name, *types)
      __getobj__.java_static_method(name, *types) || __included_method(name, types)
    end

    def declared_instance_methods(name=nil)
      __combine_methods(__getobj__.declared_instance_methods)
    end

    def declared_class_methods(name=nil)
      __combine_methods(__getobj__.declared_class_methods)
    end

    def __combine_methods(basic_methods)
      methods = {}
      basic_methods.each do |method|
        key = [method.name, method.parameter_types, method.return_type]
        methods[key] = method
      end
      @static_includes.each do |type|
        type.declared_class_methods.each do |method|
          key = [method.name, method.parameter_types, method.return_type]
          methods[key] ||= method
        end
      end
      methods.values
    end

    def __included_method(name, types)
      @static_includes.each do |type|
        method = type.meta.java_method(name, *types)
        return method if method
      end
      nil
    end
  end

  class Type
    def include(type)
      ExtendedType.new(self).include(type)
    end
  end
end