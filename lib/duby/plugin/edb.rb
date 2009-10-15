require 'erb'

Duby::AST.defmacro('def_edb') do |transformer, fcall, parent|
  name = fcall.args_node.get(0).name
  path = fcall.args_node.get(1).value
  compiler = ERB::Compiler.new(nil)
  compiler.put_cmd = "_edbout.append"
  compiler.insert_cmd = "__edb_insert__ _edbout.append"
  compiler.pre_cmd = ["def #{name}", "_edbout = StringBuilder.new"]
  compiler.post_cmd = ["_edbout.toString", "end"]
  src = compiler.compile(IO.read(path))
  ast = Duby::AST.parse_ruby(src, "(edb)")
  transformer.transform(ast.body_node, parent)
end

Duby::AST.defmacro('__edb_insert__') do |transformer, fcall, parent|
  # ERB sticks in a .to_s that we don't want.
  # the ast is __edb_insert__(_edbout.append(content.to_s))
  append = fcall.args_node.get(0)
  content = append.args_node.get(0).receiver_node
  new_args = org.jrubyparser.ast.ListNode.new(content.position, content)
  append.setArgsNode(new_args)
  transformer.transform(append, parent)
end

