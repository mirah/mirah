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