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

import java.util.Map
import javax.lang.model.type.TypeKind
import javax.lang.model.type.TypeMirror
import javax.lang.model.type.TypeVisitor
import org.mirah.jvm.mirrors.MirrorType
import javax.lang.model.util.AbstractTypeVisitor6
import javax.lang.model.util.SimpleTypeVisitor6

# Implements JLS7 15.12.2.7 Inferring Type Arguments Based on Actual Arguments
class TypeParameterInference
  class << self
    def processArgument(argument:TypeMirror,
                        constraint:char,
                        formalParameter:TypeMirror,
                        typeParameters:Map):void
      return if TypeKind.NULL == argument.getKind
      if constraint == ?<
        processExtendsConstraint(argument, formalParameter, typeParameters)
        return
      # elsif constraint == ?=
      #   processEqualConstraint(argument, formalParameter, typeParameters)
      # else # constraint == ?>
      #   processSuperConstraint(argument, formalParameter, typeParameters)
      end
      raise IllegalArgumentException
    end
  
    def processExtendsConstraint(argument:TypeMirror,
                                 formalParameter:TypeMirror,
                                 typeParameters:Map):void
      if argument.kind_of?(MirrorType) && MirrorType(argument).isPrimitive
        argument = TypeMirror(MirrorType(argument).box)
      end
      visitor = lambda(AbstractTypeVisitor6) do
        def visitTypeVariable(t, p)
          # T :> A
          a = TypeMirror(p)
          c = Constraints(typeParameters[t.toString])
          c.addSuper(a)
        end

        def visitArray(t, p)
          arg_visitor = lambda(SimpleTypeVisitor6) do
            def visitArray(v, x)
              # Recurse if argument is an array type
              TypeParameterInference.processExtendsConstraint(
                  v.getComponentType, TypeMirror(x), typeParameters)
            end
            
            # Or if argument is a type variable with an array upper bound
            def visitTypeVariable(v, x)
              v.getUpperBound.accept(self, x)
            end
          end
          TypeMirror(p).accept(arg_visitor, t)
        end
      end
    #   elsif formalParameter.isArray
    #     processExtendsConstraint(argument.getComponentType,
    #                              formalParameter.getComponentType,
    #                              typeParameters)
    #   elsif formalParameter.hasTypeParameters
    #     params = formalParameter.typeParameters
    #     args = findTypeArguments(argument, formalParameter)
    #     return unless params.size == args.size
    #     params.size.times do |i|
    #       p = params[i]
    #       a = args[i]
    #       if p.isWildcard
    #         if p.hasExtendsBound
    #           if a.isWildcard
    #             if a.hasExtendsBound
    #               processExtendsConstraint(a.extendsBound,
    #                                        p.extendsBound,
    #                                        typeParameters)
    #             end
    #           else
    #             processExtendsConstraint(a, p.extendsBound, typeParameters)
    #           end
    #         elsif p.hasSuperBound
    #           if a.isWildcard
    #             if a.hasSuperBound
    #               processSuperConstraint(a.superBound,
    #                                      p.superBound,
    #                                      typeParameters)
    #             end
    #           else
    #             processSuperConstraint(a, p.superBound, typeParameters)
    #           end
    #         end
    #       else
    #         processEqualConstraint(a, p, typeParameters)
    #       end
      # end
      formalParameter.accept(visitor, argument)
    end
    # 
    #   def processEqualConstraint(argument:MirrorType,
    #                              formalParameter:GenericType,
    #                              typeParameters:Map):void
    #     if formalParameter.isTypeVariable
    #       c = Constraints(typeParameters[formalParameter.name])
    #       c.addEqual(argument)
    #     elsif formalParameter.isArray
    #       processEqualConstraint(argument.getComponentType,
    #                              formalParameter.getComponentType,
    #                              typeParameters)
    #     elsif formalParameter.hasTypeParameters
    #       params = formalParameter.typeParameters
    #       args = findTypeArguments(argument, formalParameter)
    #       return unless params.size == args.size
    #       params.size.times do |i|
    #         p = params[i]
    #         a = args[i]
    #         if p.isWildcard
    #           if p.hasExtendsBound
    #             if a.isWildcard && a.hasExtendsBound
    #               processEqualConstraint(a.extendsBound,
    #                                      p.extendsBound,
    #                                      typeParameters)
    #             end
    #           elsif p.hasSuperBound
    #             if a.isWildcard && a.hasSuperBound
    #               processEqualConstraint(a.superBound,
    #                                      p.superBound,
    #                                      typeParameters)
    #           end
    #         else
    #           processEqualConstraint(a, p, typeParameters)
    #         end
    #       end
    #     end
    #   end
    # 
    #   def processSuperConstraint(argument:MirrorType,
    #                              formalParameter:GenericType,
    #                              typeParameters:Map):void
    #     if formalParameter.isTypeVariable
    #       c = Constraints(typeParameters[formalParameter.name])
    #       c.addExtends(argument)
    #     elsif formalParameter.isArray
    #       processSuperConstraint(argument.getComponentType,
    #                              formalParameter.getComponentType,
    #                              typeParameters)
    #     elsif formalParameter.hasTypeParameters
    #       return unless isGenericSupertype(argument, formalParameter)
    #       params = formalParameter.typeParameters
    #       args = findTypeArguments(argument, formalParameter)
    #       return unless params.size == args.size
    #       params.size.times do |i|
    #         p = params[i]
    #         a = args[i]
    #         if p.isWildcard
    #         else
    #         end
    #       end
    #     end
  end
end