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
    @max_errors = 20
  end

  def setMaxErrors(count:int):void
    @max_errors = count
  end

  def errorCount; @errors; end

  def log(kind:Kind, position:String, message:String):void
    System.err.println(position) if position
    System.err.print(@prefixes[kind])
    System.err.println(message)
  end

  def report(diagnostic)
    @errors += 1 if Kind.ERROR == diagnostic.getKind
    source = CodeSource(diagnostic.getSource) if diagnostic.getSource.kind_of?(CodeSource)
    position = if source
      String.format("%s:%d:%n", source.name, diagnostic.getLineNumber)
    end
    message = diagnostic.getMessage(Locale.getDefault)
    if source
      buffer = StringBuffer.new(message)
      newline = String.format("%n")
      buffer.append(newline)
      
      target_line = Math.max(0, int(diagnostic.getLineNumber - source.initialLine))
      start_col = if target_line == 0
        diagnostic.getColumnNumber - source.initialColumn
      else
        diagnostic.getColumnNumber - 1
      end
      start_col = long(0) if start_col < 0
      lines = @newline.split(source.contents)
      if target_line < lines.length
        line = lines[target_line]
        buffer.append(line)
        buffer.append(newline)
        space = char[int(start_col)]
        prefix = line.substring(0,int(start_col))
        prefix.length.times do |i|
          c = prefix.charAt(i) 
          if Character.isWhitespace(c)
            space[i] = c
          else
            space[i] = char(32) 
          end
        end
        buffer.append(space)
        length = Math.min(diagnostic.getEndPosition - diagnostic.getStartPosition,
                          line.length - start_col)
        underline = char[int(Math.max(length, 1))]
        Arrays.fill(underline, char(94))
        buffer.append(underline)
        message = buffer.toString
      end
    end
    log(diagnostic.getKind, position, message)
    if @errors > @max_errors && @max_errors > 0
      raise TooManyErrorsException
    end
  end
end