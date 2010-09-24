require 'erb'

Duby::AST.defmacro('def_edb') do |transformer, fcall, parent|
  name = fcall.parameters[0].name
  path = fcall.parameters[1].literal
  compiler = ERB::Compiler.new(nil)
  compiler.put_cmd = "_edbout.append"
  compiler.insert_cmd = "__edb_insert__ _edbout.append"
  compiler.pre_cmd = ["def #{name}", "_edbout = StringBuilder.new"]
  compiler.post_cmd = ["_edbout.toString", "end"]
  src = compiler.compile(IO.read(path))
  ast = Duby::AST.parse_ruby(src, path)
  transformer.filename = path
  script = transformer.transform(ast, parent)
  script.body.parent = parent
  script.body
end

Duby::AST.defmacro('__edb_insert__') do |transformer, fcall, parent|
  # ERB sticks in a .to_s that we don't want.
  # the ast is __edb_insert__(_edbout.append(content.to_s))
  append = fcall.parameters[0]
  content = append.parameters[0].target
  content.parent = append
  append.parameters = [content]
  append.parent = parent
  append
end

