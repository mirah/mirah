require 'java'
require 'duby'

java_package "org.jruby.duby"
class DubyCommand
  java_signature "void main(String[])"
  def self.main(args)
    rb_args = args.to_a
    command = rb_args.shift.to_s
    case command
    when "compile"
      Duby.compile(*rb_args)
    when "run"
      Duby.run(*rb_args)
    end
  end
end