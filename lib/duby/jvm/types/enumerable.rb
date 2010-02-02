module Duby::JVM::Types
  class Type
    def expand_each(transformer, call)
      arg_types = [Duby::AST.block_type]
      code = intrinsics['each'][arg_types].return_type
      code.inline(transformer, call)
    end
    
    def add_enumerable_macros
      add_macro('all?') do |transformer, call|
        if !call.block
          var = transformer.tmp
          call.block = transformer.eval("foo {|#{var}| #{var}}").block
        end
        forloop = expand_each(transformer, call)
        all = transformer.tmp
        forloop.init << transformer.eval("#{all} = true")
        body = transformer.eval(
            "unless foo;#{all} = false;break;end", '', forloop)
        body.condition.predicate = call.block.body
        forloop.body = call.block.body.parent = body
        
        result = Duby::AST::Body.new(call.parent, call.position)
        result << forloop << transformer.eval("#{all}", '', nil, all)
      end
      intrinsics['all?'][[Duby::AST.block_type]] = intrinsics['all?'][[]]

      add_macro('any?') do |transformer, call|
        if !call.block
          var = transformer.tmp
          call.block = transformer.eval("foo {|#{var}| #{var}}").block
        end
        forloop = expand_each(transformer, call)
        any = transformer.tmp
        forloop.init << transformer.eval("#{any} = false")
        body = transformer.eval(
            "if foo;#{any} = true;break;end", '', forloop)
        body.condition.predicate = call.block.body
        forloop.body = call.block.body.parent = body
        
        result = Duby::AST::Body.new(call.parent, call.position)
        result << forloop << transformer.eval("#{any}", '', nil, any)
      end
      intrinsics['any?'][[Duby::AST.block_type]] = intrinsics['any?'][[]]
    end
  end
end