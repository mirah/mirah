require 'java'
require 'mirah'
java_import 'java.util.List'

java_package "org.jruby.duby"
class DubyCommand
  java_signature "void main(String[])"
  def self.main(args)
    rb_args = args.to_a
    command = rb_args.shift.to_s
    case command
    when "compile"
      DubyCommand.compile(rb_args)
    when "run"
      DubyCommand.run(rb_args)
    end
  end

  java_signature 'void compile(List args)'
  def self.compile(args)
    Duby.compile(*args)
  end

  java_signature 'void run(List args)'
  def self.run(args)
    Duby.run(*args)
  end
end