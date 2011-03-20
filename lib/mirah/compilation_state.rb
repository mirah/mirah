module Mirah
  class CompilationState
    def initialize
      BiteScript.bytecode_version = BiteScript::JAVA1_5
      @save_extensions = true
    end

    attr_accessor :verbose, :destination
    attr_accessor :version_printed
    attr_accessor :help_printed
    attr_accessor :save_extensions

    def set_jvm_version(ver_str)
      case ver_str
      when '1.4'
        BiteScript.bytecode_version = BiteScript::JAVA1_4
      when '1.5'
        BiteScript.bytecode_version = BiteScript::JAVA1_5
      when '1.6'
        BiteScript.bytecode_version = BiteScript::JAVA1_6
      when '1.7'
        BiteScript.bytecode_version = BiteScript::JAVA1_7
      else
        $stderr.puts "invalid bytecode version specified: #{ver_str}"
      end
    end
  end
end