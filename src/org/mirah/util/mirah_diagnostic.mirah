package org.mirah.util

import javax.tools.Diagnostic
import mirah.lang.ast.Position

class MirahDiagnostic implements Diagnostic
  def initialize(kind:Diagnostic.Kind, position:Position, message:String)
    @kind = kind
    @position = position
    @message = String
  end
  
  def self.error(position:Position, message:String)
    MirahDiagnostic.new(Diagnostic.Kind.ERROR, position, message)
  end
  
  def self.warning(position:Position, message:String)
    MirahDiagnostic.new(Diagnostic.Kind.WARNING, position, message)
  end
  
  def self.node(position:Position, message:String)
    MirahDiagnostic.new(Diagnostic.Kind.NOTE, position, message)
  end
  
  def getKind
    @kind
  end
  
  def getMessage(locale)
    @message
  end
  
  def getSource
    @position.source if @position
  end
  
  #TODO
  def getCode; nil; end
  
  def getColumnNumber
    if @position
      @position.startColumn
    else
      Diagnostic.NOPOS
    end
  end
  
  def getEndPosition
    if @position
      @position.endChar
    else
      Diagnostic.NOPOS
    end
  end
  
  def getLineNumber
    if @position
      @position.startLine
    else
      Diagnostic.NOPOS
    end
  end
  
  def getPosition
    if @position
      @position.startChar
    else
      Diagnostic.NOPOS
    end
  end
  
  def getStartPosition
    getPosition
  end
end