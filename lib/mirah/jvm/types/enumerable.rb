module Duby::JVM::Types
  class Type
    def expand_each(transformer, call)
      arg_types = [Duby::AST.block_type]
      code = intrinsics['each'][arg_types].return_type
      code.inline(transformer, call)
    end
    
    def add_enumerable_macros
      all_proc = proc do |transformer, call|
        if !call.block
          # We need to create a block that just returns the item passed to it
          # First get a new temp for the block argument
          var = transformer.tmp
          # Parse a fake function call to create a block. Then pull of the
          # block and attach it to the real call.
          call.block = transformer.eval("foo {|#{var}| #{var}}").block
        end
        
        # Now that we've got a block we can transform it into a Loop.
        forloop = expand_each(transformer, call)
        
        # Start adding stuff to the loop.
        # At the beginning of the loop we create a temp initialized to true
        all = transformer.tmp
        forloop.init << transformer.eval("#{all} = true")
        
        # Now we want to wrap the body of the loop. Start off by using
        # foo as a placeholder.
        body = transformer.eval(
            "unless foo;#{all} = false;break;end", '', forloop)
        # Then replace foo with the real body.
        body.condition.predicate = call.block.body
        # And finally patch the new body back into the forloop.
        forloop.body = call.block.body.parent = body
        
        # Loops don't have a return value, so we need somewhere to
        # put the result.
        result = Duby::AST::Body.new(call.parent, call.position)
        result << forloop << transformer.eval("#{all}", '', nil, all)
      end
      add_macro('all?', &all_proc)
      add_macro('all?', Duby::AST.block_type, &all_proc)

      any_proc = proc do |transformer, call|
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
      add_macro('any?', &any_proc)
      add_macro('any?', Duby::AST.block_type, &any_proc)
    end
  end
end