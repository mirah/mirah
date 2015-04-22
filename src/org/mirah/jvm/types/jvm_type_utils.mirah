package org.mirah.jvm.types

import mirah.objectweb.asm.Opcodes
import mirah.objectweb.asm.Type
import mirah.objectweb.asm.Opcodes
import mirah.lang.ast.AnnotationList
import mirah.lang.ast.Annotation
import mirah.lang.ast.HashEntry
import mirah.lang.ast.Array
import mirah.lang.ast.Node
import mirah.lang.ast.Annotated
import mirah.lang.ast.HasModifiers
import mirah.lang.ast.Modifier
import mirah.lang.ast.Identifier
import java.util.logging.Logger
import java.util.logging.Level

class JVMTypeUtils
    # defining initialize in class << self does not work
    def self.initialize
       @@ACCESS = {
          PUBLIC: Opcodes.ACC_PUBLIC,
          PRIVATE: Opcodes.ACC_PRIVATE,
          PROTECTED: Opcodes.ACC_PROTECTED,
          DEFAULT: 0
        }
        @@FLAGS = {
          STATIC: Opcodes.ACC_STATIC,
          FINAL: Opcodes.ACC_FINAL,
          SUPER: Opcodes.ACC_SUPER,
          SYNCHRONIZED: Opcodes.ACC_SYNCHRONIZED,
          VOLATILE: Opcodes.ACC_VOLATILE,
          BRIDGE: Opcodes.ACC_BRIDGE,
          VARARGS: Opcodes.ACC_VARARGS,
          TRANSIENT: Opcodes.ACC_TRANSIENT,
          NATIVE: Opcodes.ACC_NATIVE,
          INTERFACE: Opcodes.ACC_INTERFACE,
          ABSTRACT: Opcodes.ACC_ABSTRACT,
          STRICT: Opcodes.ACC_STRICT,
          SYNTHETIC: Opcodes.ACC_SYNTHETIC,
          ANNOTATION: Opcodes.ACC_ANNOTATION,
          ENUM: Opcodes.ACC_ENUM,
          DEPRECATED: Opcodes.ACC_DEPRECATED
        }
      @@log = Logger.getLogger(JVMTypeUtils.class.getName)
  end

  class << self
    
    def isPrimitive(type:JVMType)
      if type.isError
        return false
      end
      sort = type.getAsmType.getSort
      sort != Type.OBJECT && sort != Type.ARRAY
    end

    def isEnum(type:JVMType):boolean
      0 != (type.flags & Opcodes.ACC_ENUM)
    end

    def isInterface(type:JVMType):boolean
      0 != (type.flags & Opcodes.ACC_INTERFACE)
    end

    def isAbstract(type:JVMType):boolean
      0 != (type.flags & Opcodes.ACC_ABSTRACT)
    end

    def isAnnotation(type:JVMType):boolean
      0 != (type.flags & Opcodes.ACC_ANNOTATION)
    end

    def isArray(type:JVMType):boolean
      type.getAsmType.getSort == Type.ARRAY
    end

    def calculateFlags(defaultAccess:int, node:Node):int        

        access = defaultAccess
        flags = 0        
        return defaultAccess unless node

        if HasModifiers.class.isAssignableFrom(node.getClass)           
          modifiers = HasModifiers(node).modifiers
          if modifiers
          modifiers.each do |m: Modifier|
            key = m.value
            accss = @@ACCESS[key]
            if accss
                access = Integer(accss).intValue
            end
            flag = @@FLAGS[key]
            if flag
                flags |= Integer(flag).intValue
            end
          end 
          end
        end 
        
        @@log.fine "calculated flag from modifiers: #{flags} access:#{access}"

        if Annotated.class.isAssignableFrom(node.getClass)
          annotations = Annotated(node).annotations  
          if annotations
          annotations.each do |anno: Annotation|
            next unless "org.mirah.jvm.types.Modifiers".equals(anno.type.typeref.name)
            anno.values.each do |entry: HashEntry|
              key = Identifier(entry.key).identifier

              if "access".equals(key)
                #access = @@ACCESS[Identifier(entry.value).identifier] # TODO better boxing
                access = Integer(@@ACCESS[Identifier(entry.value).identifier]).intValue
              elsif "flags".equals(key) # TODO better boxing
                values = Array(entry.value)
                values.values.each do |id: Identifier| # cast from Node
                    flag = id.identifier
                    flags |= Integer(@@FLAGS[flag]).intValue 
                end
              else
                raise "unknown modifier entry: #{entry}"
              end
            end
          end 
          end
        end
  
        @@log.fine "calculated flag from annotations: #{flags} access:#{access}"
        
        flags | access
    end
  end
end