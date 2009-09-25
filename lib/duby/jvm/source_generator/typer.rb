require 'duby/jvm/typer'
require 'duby/jvm/source_generator/builder'

module Duby
  module Typer
    class JavaSource < JVM
      include Duby::JVM::Types
      
    end
  end
end