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

package org.mirah.jvm.mirrors.generics

import java.util.Collections
import java.util.LinkedList
import java.util.List
import java.util.Map
import javax.lang.model.type.ArrayType
import javax.lang.model.type.DeclaredType
import javax.lang.model.type.TypeKind
import javax.lang.model.type.TypeMirror
import javax.lang.model.type.TypeVisitor
import javax.lang.model.type.WildcardType
import javax.lang.model.util.AbstractTypeVisitor6
import javax.lang.model.util.SimpleTypeVisitor6
import javax.lang.model.util.Types
import org.mirah.jvm.mirrors.MirrorType
import org.objectweb.asm.Type

import org.mirah.jvm.types.JVMTypeUtils

# Implements JLS7 15.12.2.7 Inferring Type Arguments Based on Actual Arguments
class TypeParameterInference

  def initialize(types:Types)
    @types = types
  end

  def processArgument(argument:TypeMirror,
                      constraint:char,
                      formalParameter:TypeMirror,
                      typeParameters:Map):void
    return if TypeKind.NULL == argument.getKind
    if constraint == ?<
      processExtendsConstraint(argument, formalParameter, typeParameters)
      return
    elsif constraint == ?=
      processEqualConstraint(argument, formalParameter, typeParameters)
      return
    elsif constraint == ?>
      processSuperConstraint(argument, formalParameter, typeParameters)
      return
    end
    raise IllegalArgumentException, "Invalid constraint #{constraint}"
  end

  def processExtendsConstraint(argument:TypeMirror,
                               formalParameter:TypeMirror,
                               typeParameters:Map):void
    if argument.kind_of?(MirrorType) &&
        JVMTypeUtils.isPrimitive(MirrorType(argument))
      argument = MirrorType(MirrorType(argument).box)
    end
    tpi = self
    visitor = lambda(SimpleTypeVisitor6) do
      def visitTypeVariable(t, p)
        # T :> A
        a = TypeMirror(p)
        c = Constraints(typeParameters[t.toString])
        c.addSuper(a) if c
      end

      def visitArray(t, p)
        arg_visitor = lambda(SimpleTypeVisitor6) do
          def visitArray(v, x)
            # Recurse if argument is an array type
            ArrayType(x).getComponentType.accept(visitor, v.getComponentType)
          end
          
          # Or if argument is a type variable with an array upper bound
          def visitTypeVariable(v, x)
            v.getUpperBound.accept(self, x)
          end
        end
        TypeMirror(p).accept(arg_visitor, t)
      end

      def visitDeclared(t, p)
        return nil if t.getTypeArguments.isEmpty
        params = t.getTypeArguments.iterator
        args = tpi.findExtendsTypeArguments(TypeMirror(p), t).iterator
        while args.hasNext
          arg = TypeMirror(args.next)
          param = TypeMirror(params.next)
          if param.getKind != TypeKind.WILDCARD
            tpi.processEqualConstraint(arg, param, typeParameters)
          else
            wildcard_param = tpi.wildcard(param)
            if wildcard_param.getExtendsBound
              if arg.getKind != TypeKind.WILDCARD
                tpi.processExtendsConstraint(
                    arg, wildcard_param.getExtendsBound,
                    typeParameters)
              else
                wildcard_arg = tpi.wildcard(arg)
                if wildcard_arg.getExtendsBound
                  tpi.processExtendsConstraint(
                      wildcard_arg.getExtendsBound,
                      wildcard_param.getExtendsBound,
                      typeParameters)
                end
              end
            elsif wildcard_param.getSuperBound
              if arg.getKind != TypeKind.WILDCARD
                tpi.processSuperConstraint(
                    arg,
                    wildcard_param.getSuperBound,
                    typeParameters)
              else
                wildcard_arg = tpi.wildcard(arg)
                if wildcard_arg.getSuperBound
                  tpi.processSuperConstraint(
                      wildcard_arg.getSuperBound,
                      wildcard_param.getSuperBound,
                      typeParameters)
                end
              end
            end
          end
        end
      end
    end
    formalParameter.accept(visitor, argument) if formalParameter
  end

  def processEqualConstraint(argument:TypeMirror,
                             formalParameter:TypeMirror,
                             typeParameters:Map):void
    tpi = self
    visitor = lambda(SimpleTypeVisitor6) do
      def visitTypeVariable(t, p)
        c = Constraints(typeParameters[t.toString])
        c.addEqual(TypeMirror(p)) if c
      end

      def visitArray(t, p)
        arg_visitor = lambda(SimpleTypeVisitor6) do
          def visitArray(v, x)
            # Recurse if argument is an array type
            ArrayType(x).getComponentType.accept(visitor, v.getComponentType)
          end
          
          # Or if argument is a type variable with an array upper bound
          def visitTypeVariable(v, x)
            v.getUpperBound.accept(self, x)
          end
        end
        TypeMirror(p).accept(arg_visitor, t)
      end
      
      def visitDeclared(t, p)
        return nil if t.getTypeArguments.isEmpty
        params = t.getTypeArguments.iterator
        args = tpi.findEqualTypeArguments(
            TypeMirror(p), t).iterator
        while args.hasNext
          arg = TypeMirror(args.next)
          param = TypeMirror(params.next)
          if param.getKind != TypeKind.WILDCARD
            tpi.processEqualConstraint(arg, param, typeParameters)
          else
            wildcard_param = tpi.wildcard(param)
            if wildcard_param.getExtendsBound
              if arg.getKind == TypeKind.WILDCARD
                wildcard_arg = tpi.wildcard(arg)
                if wildcard_arg.getExtendsBound
                  tpi.processEqualConstraint(
                      wildcard_arg.getExtendsBound,
                      wildcard_param.getExtendsBound,
                      typeParameters)
                end
              end
            elsif wildcard_param.getSuperBound
              if arg.getKind == TypeKind.WILDCARD
                wildcard_arg = tpi.wildcard(arg)
                if wildcard_arg.getSuperBound
                  tpi.processEqualConstraint(
                      wildcard_arg.getSuperBound,
                      wildcard_param.getSuperBound,
                      typeParameters)
                end
              end
            end
          end
        end
      end
    end
    formalParameter.accept(visitor, argument)
  end

  def processSuperConstraint(argument:TypeMirror,
                             formalParameter:TypeMirror,
                             typeParameters:Map):void
    tpi = self
    visitor = lambda(SimpleTypeVisitor6) do
      def visitTypeVariable(t, p)
        # T <: A
        c = Constraints(typeParameters[t.toString])
        c.addExtends(TypeMirror(p)) if c
      end

      def visitArray(t, p)
        arg_visitor = lambda(SimpleTypeVisitor6) do
          def visitArray(v, x)
            # Recurse if argument is an array type
            ArrayType(x).getComponentType.accept(visitor, v.getComponentType)
          end
          
          # Or if argument is a type variable with an array upper bound
          def visitTypeVariable(v, x)
            v.getUpperBound.accept(self, x)
          end
        end
        TypeMirror(p).accept(arg_visitor, t)
      end
      
      def visitDeclared(t, p)
        types2 = tpi.findMatchingGenericSupertypes(TypeMirror(p), t)
        return nil if types2.nil? # FIXME: a compiler bug prevents types2 being called types.
        args = types2[0].getTypeArguments.iterator
        params = types2[1].getTypeArguments.iterator
        while args.hasNext
          arg = TypeMirror(args.next)
          param = TypeMirror(params.next)
          wildcard_arg = tpi.wildcard(arg)
          if param.getKind != TypeKind.WILDCARD
            if wildcard_arg.nil?
              tpi.processEqualConstraint(
                  arg, param, typeParameters)
            else
              if wildcard_arg.getExtendsBound
                tpi.processSuperConstraint(
                    wildcard_arg.getExtendsBound, param, typeParameters)
              elsif wildcard_arg.getSuperBound
                tpi.processExtendsConstraint(
                    wildcard_arg.getSuperBound, param, typeParameters)
              end
            end
          else
            wildcard_param = tpi.wildcard(param)
            if wildcard_param.getExtendsBound
              if wildcard_arg && wildcard_arg.getExtendsBound
                tpi.processSuperConstraint(
                    wildcard_arg.getExtendsBound,
                    wildcard_param.getExtendsBound,
                    typeParameters)
              end
            elsif wildcard_param.getSuperBound
              if wildcard_arg && wildcard_arg.getSuperBound
                tpi.processExtendsConstraint(
                    wildcard_arg.getSuperBound,
                    wildcard_param.getSuperBound,
                    typeParameters)
              end
            end
          end
        end
      end
    end
    formalParameter.accept(visitor, argument)
  end

  def findExtendsTypeArguments(arg:TypeMirror, param:DeclaredType):List
    type = findMatchingSupertype(arg, param)
    if type
      type.getTypeArguments
    else
      Collections.emptyList
    end
  end

  def findEqualTypeArguments(arg:TypeMirror, param:DeclaredType):List
    if arg.getKind == TypeKind.DECLARED
      if @types.asElement(arg).equals(@types.asElement(param))
        return DeclaredType(arg).getTypeArguments
      end
    end
    Collections.emptyList
  end

  def findMatchingSupertype(subtype:TypeMirror,
                            supertype:DeclaredType):DeclaredType
    super_elem = @types.asElement(supertype)
    types = LinkedList.new
    types.add(subtype)
    while types.size > 0
      t = TypeMirror(types.removeFirst)
      if t.getKind == TypeKind.DECLARED
        if @types.asElement(t).equals(super_elem)
          return DeclaredType(t)
        end
      end
      types.addAll(@types.directSupertypes(t))
    end
    nil
  end

  def findMatchingGenericSupertypes(arg:TypeMirror,
                                    param:DeclaredType):DeclaredType[]
    if arg.getKind == TypeKind.DECLARED
      argType = DeclaredType(arg)
      unless argType.getTypeArguments.isEmpty
        param = findMatchingSupertype(param, argType)
        result = DeclaredType[2]
        result[0] = argType
        result[1] = param
        return result
      end
    end
    nil
  end
  
  def wildcard(type:TypeMirror):WildcardType
    if type.getKind == TypeKind.WILDCARD
      WildcardType(type)
    end
  end
end