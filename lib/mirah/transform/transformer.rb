module Mirah
  module Transform
    class Transformer
      begin
        java_import 'org.mirah.macros.Compiler'
      rescue NameError
        $CLASSPATH << File.dirname(__FILE__) + '/../../../javalib/mirah-bootstrap.jar'
      end

      attr_reader :errors, :state
      attr_accessor :filename
      def initialize(state, typer)
        @errors = []
        @tmp_count = 0
        @annotations = []
        @extra_body = nil
        @state = state
        @typer = typer
        @types = typer.type_system if typer
        @files = {""=>{:filename => "", :line => 0, :code => ""}}
      end

      def tmp(format="__xform_tmp_%d")
        format % [@tmp_count += 1]
      end

      class JMetaPosition
        attr_accessor :start_line, :end_line, :start_offset, :end_offset, :file
        attr_accessor :startpos, :endpos, :start_column, :end_column, :source

        def initialize(transformer, startpos, endpos, source)
          @startpos = startpos
          @endpos = endpos
          @transformer = transformer
          @start_line = startpos.line
          @start_offset = startpos.pos
          @start_column = startpos.col
          @end_line = endpos.line
          @end_offset = endpos.pos
          @end_column = endpos.col
          @source = source
        end
      end
    end
  end
end