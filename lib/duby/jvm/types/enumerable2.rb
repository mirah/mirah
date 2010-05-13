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
          # Parse a fake function call to create a block. Then pull of the
          # block and attach it to the real call.
          call.block = transformer.eval("foo {|x| x}").block
        end

        transformer.evalf(<<-EOF, call.target, block.arguments, block.body)
          all = true
          $%1.each do |$%2|
            unless $%3
              all = false
              break
            end
          end
          all
        EOF
      end
      add_macro('all?', &all_proc)
      add_macro('all?', Duby::AST.block_type, &all_proc)

      any_proc = proc do |transformer, call|
        if !call.block
          call.block = transformer.eval("foo {|x| x}").block
        end
        transformer.evalf(<<-EOF, call.target, block.arguments, block.body)
          any = false
          $%1.each do |$%2|
            if $%3
              any = true
              break
            end
          end
          any
        EOF
      end
      add_macro('any?', &any_proc)
      add_macro('any?', Duby::AST.block_type, &any_proc)
    end
  end
end