require 'java'
require 'mirah'
java_import 'java.util.List'

java_package "org.mirah"
class MirahCommand
  java_signature "void main(String[])"
  def self.main(args)
    rb_args = args.to_a
    command = rb_args.shift.to_s
    case command
    when "compile"
      MirahCommand.compile(rb_args)
    when "run"
      MirahCommand.run(rb_args)
    end
  end

  java_signature 'void compile(List args)'
  def self.compile(args)
    Mirah.compile(*args)
  end

  java_signature 'void run(List args)'
  def self.run(args)
    Mirah.run(*args)
  end
end