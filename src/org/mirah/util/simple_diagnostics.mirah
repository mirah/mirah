package org.mirah.util

import java.util.Arrays
import java.util.HashMap
import java.util.Locale
import javax.tools.Diagnostic.Kind
import javax.tools.DiagnosticListener
import mirah.lang.ast.CodeSource

class TooManyErrorsException < RuntimeException; end

class SimpleDiagnostics; implements DiagnosticListener
  def initialize(color:boolean)
    @errors = 0
    @newline = /\r?\n/
    @prefixes = HashMap.new
    if color
      @prefixes.put(Kind.ERROR, "\e[1m\e[31mERROR\e[0m: ")
      @prefixes.put(Kind.MANDATORY_WARNING, "\e[1m\e[33mWARNING\e[0m: ")
      @prefixes.put(Kind.WARNING, "\e[1m\e[33mWARNING\e[0m: ")
      @prefixes.put(Kind.NOTE, "")
      @prefixes.put(Kind.OTHER, "")
    else
      @prefixes.put(Kind.ERROR, "ERROR: ")
      @prefixes.put(Kind.MANDATORY_WARNING, "WARNING: ")
      @prefixes.put(Kind.WARNING, "WARNING: ")
      @prefixes.put(Kind.NOTE, "")
      @prefixes.put(Kind.OTHER, "")
    end
  end
  
  def errorCount; @errors; end
  
  def report(diagnostic)
    @errors += 1 if Kind.ERROR == diagnostic.getKind
    source = CodeSource(diagnostic.getSource) if diagnostic.getSource.kind_of?(CodeSource)
    System.err.println("#{source.name}:#{diagnostic.getLineNumber}:") if source
    System.err.print(@prefixes[diagnostic.getKind])
    System.err.println(diagnostic.getMessage(Locale.getDefault))
    if source
      target_line = int(diagnostic.getLineNumber - source.initialLine)
      start_col = if target_line == 0
        diagnostic.getColumnNumber - source.initialColumn
      else
        diagnostic.getColumnNumber - 1
      end
      lines = @newline.split(source.contents)
      if target_line < lines.length
        line = lines[target_line]
        System.err.println(line)
        space = char[int(start_col)]
        Arrays.fill(space, char(32))
        System.err.print(space)
        length = Math.min(diagnostic.getEndPosition - diagnostic.getStartPosition,
                          line.length - start_col)
        underline = char[int(Math.max(length, 1))]
        Arrays.fill(underline, char(94))
        System.err.println(underline)
      end
    end
    raise TooManyErrorsException if @errors > 20
  end
end