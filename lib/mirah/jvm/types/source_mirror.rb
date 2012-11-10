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

require 'jruby'
require 'set'
require 'bitescript'
module Mirah::JVM::Types
  class JavaSourceMirror
    begin
      java_import 'javax.tools.ToolProvider'
      java_import 'java.util.Arrays'
      java_import 'javax.tools.SimpleJavaFileObject'
      java_import 'javax.tools.JavaFileObject'
      java_import 'java.net.URI'
      java_import 'javax.lang.model.element.Element'
      java_import 'javax.lang.model.type.TypeKind'
      java_import 'javax.lang.model.type.TypeMirror'
      java_import 'com.sun.tools.javac.model.JavacElements'
      java_import 'javax.lang.model.util.ElementScanner6'
      java_import 'javax.lang.model.element.AnnotationValueVisitor'
    rescue
    end

    if defined?(JavacElements)
      class FakeJavaFile < SimpleJavaFileObject
        def initialize(package, name, kind='class')
          package ||= ''
          super(URI.create(FakeJavaFile.build_uri(package, name)), JavaFileObject::Kind::SOURCE)
          @code = ''
          if package != ""
            @code << "package #{package};\n"
          end
          @code << "@org.mirah.infer.FakeClass\n"
          @code << "public #{kind} #{name} { }"
        end

        def self.build_uri(package, name)
          name = name.tr('.', '$')
          package = package.tr('.', '/')
          package << '/' unless "" == package
          "string:///#{package}#{name}#{JavaFileObject::Kind::SOURCE.extension}"
        end

        def getCharContent(ignoreEncodingErrors)
          java.lang.String.new(@code)
        end
      end

      class JavaSourceParser < ElementScanner6
        include AnnotationValueVisitor

        # TODO support generics
        def initialize(file, type_factory)
          super()
          @file = file
          @type_factory = type_factory
          @mirrors = []
        end

        def parse
          tools = ToolProvider.system_java_compiler
          units = [get_java_file(tools)] + get_fake_files
          @javac = tools.get_task(nil, nil, nil, classpath, nil, units)
          @element_utils = JavacElements.instance(@javac.context)
          elements = @javac.enter
          elements.each {|elem| scan(elem)}
          @mirrors
        end

        def classpath
          options = [
            '-classpath', @type_factory.classpath
          ]
          if @type_factory.bootclasspath
            options << '-bootclasspath' << @type_factory.bootclasspath
          end
          options
        end

        def get_java_file(tools)
          fm = tools.get_standard_file_manager(nil, nil, nil)
          fm.get_java_file_objects(@file).to_a[0]
        end

        def get_fake_files
          mirah_typedefs = Set.new(@type_factory.known_types.values.reject {|t| !t.kind_of?(TypeDefinition)})
          files = [FakeJavaFile.new('org.mirah.infer', 'FakeClass', '@interface')]
          mirah_typedefs.each do |typedef|
            typedef.name =~ /^(?:(.+)\.)?([^.]+)$/
            package, name = $1, $2
            kind = if typedef.interface?
              'interface'
            else
              'class'
            end
            files << FakeJavaFile.new(package, name, kind)
          end
          files
        end

        def visitType(elem, arg)
          return anno_visitType(elem, arg) if elem.kind_of?(TypeMirror)
          if elem.annotation_mirrors.any? {|a| a.toString == '@org.mirah.infer.FakeClass'}
            return
          end
          superclass = internal_type_name(elem.superclass) || 'java/lang/Object'
          interfaces = elem.interfaces.map {|i| internal_type_name(i)}
          flags = flags_from_modifiers(elem)
          builder = BiteScript::ASM::ClassMirror::Builder.new
          builder.visit(0, flags, internal_name(elem), nil, superclass, interfaces)
          with(builder) do
            elem.annotation_mirrors.each {|anno| visitAnnotation(anno)}
            super(elem, arg)
          end
          @mirrors << builder.mirror
          builder.mirror
        end

        def visitVariable(field, arg)
          flags = flags_from_modifiers(field)
          type = type_desc(field.as_type)
          fbuilder = @current.visitField(
            flags, field.simple_name, type, nil, field.constant_value)
          with fbuilder do
            field.annotation_mirrors.each {|anno| visitAnnotation(anno)}
          end
        end

        def visitExecutable(method, arg)
          # TODO varags
          flags = flags_from_modifiers(method)
          exceptions = method.thrown_types.map {|t| internal_type_name(t)}
          desc = type_desc(method.as_type)
          mbuilder = @current.visitMethod(flags, method.simple_name, desc, nil, exceptions)
          with mbuilder do
            method.annotation_mirrors.each {|anno| visitAnnotation(anno)}
          end
        end

        def visitAnnotation(elem, arg=nil)
          desc = type_desc(elem.annotation_type)
          if arg.nil?
            anno = @current.visitAnnotation(desc, 0)
          else
            builder, name = arg
            anno = builder.visitAnnotation(name, desc)
          end
          elem.element_values.each do |method, value|
            name = method.simple_name
            visit(value, [anno, name])
          end
        end

        # AnnotationValueVisitor
        def visitArray(values, arg)
          anno, name = arg
          array = anno.visitArray(name)
          values.each do |value|
            visit(value, [array, name])
          end
        end

        def visitBoolean(val, arg)
          anno, name = arg
          anno.visit(name, val)
        end
        alias visitByte visitBoolean
        alias visitChar visitBoolean
        alias visitDouble visitBoolean
        alias visitFloat visitBoolean
        alias visitInt visitBoolean
        alias visitLong visitBoolean
        alias visitShort visitBoolean
        alias visitString visitBoolean
        alias visitUnknown visitBoolean

        def visitEnumConstant(c, arg)
          anno, name = arg
          anno.visitEnum(name, type_desc(c.as_type), c.simple_name)
        end

        def anno_visitType(t, arg)
          anno, name = arg
          anno.visit(name, BiteScript::ASM::Type.getType(type_desc(t)))
        end

        def with(elem)
          saved, @current = @current, elem
          begin
            yield
          ensure
            @current = saved
          end
        end

        def flags_from_modifiers(elem)
          flags = 0
          elem.modifiers.each do |modifier|
            flags |= BiteScript::ASM::Opcodes.const_get("ACC_#{modifier.name}")
          end
          flags
        end

        def internal_name(element)
          @element_utils.get_binary_name(element).to_s.tr('.', '/')
        end

        def internal_type_name(type)
          return nil if type.kind == TypeKind::NONE
          return @element_utils.get_binary_name(type.as_element).to_s.tr('.', '/')
        end

        def type_desc(type)
          case type.kind.name
          when 'ARRAY'
            "[#{type_desc(type.component_type)}"
          when 'BOOLEAN'
            'Z'
          when 'BYTE'
            'B'
          when 'CHAR'
            'C'
          when 'DECLARED'
            name = internal_type_name(type)
            "L#{name};"
          when 'DOUBLE'
            'D'
          when 'FLOAT'
            'F'
          when 'INT'
            'I'
          when 'LONG'
            'J'
          when 'SHORT'
            'S'
          when 'VOID'
            'V'
          when 'EXECUTABLE'
            desc = '('
            type.parameter_types.each do |param|
              desc << type_desc(param)
            end
            desc << ')'
            desc << type_desc(type.return_type)
          else
            raise ArgumentError, "Unsupported type #{type.kind.name}"
          end
        end
      end
    end

    def self.load(file, factory)
      parser = JavaSourceParser.new(file, factory)
      parser.parse
    end
  end
end
