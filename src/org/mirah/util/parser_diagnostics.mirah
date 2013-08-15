package org.mirah.util

import java.util.ArrayList
import javax.tools.Diagnostic
import javax.tools.Diagnostic.Kind
import javax.tools.DiagnosticListener

# Buffers warnings and only prints them if there's a syntax error.
class ParserDiagnostics; implements DiagnosticListener
  def initialize(out:DiagnosticListener)
    @buffer = ArrayList.new
    @out = out
    @buffering = true
  end
  def report(diagnostic)
    if Kind.ERROR.equals(diagnostic.getKind)
      @buffer.each do |d:Diagnostic|
        @out.report(d)
      end
      @buffer.clear
      @buffering = false
      @out.report(diagnostic)
    elsif @buffering
      @buffer.add(diagnostic)
    else
      @out.report(diagnostic)
    end
  end
end
