package org.mirah

import java.io.PrintWriter
import java.io.StringWriter
import java.util.Arrays
import java.util.List
import org.mirah.util.Logger
import java.util.logging.Formatter
import java.util.logging.ConsoleHandler
import java.util.logging.Level

class MirahLogFormatter < Formatter
  def initialize(use_color:boolean)
    @color = use_color
    @names = {}
    @inverse_names = {}
  end

  def format_name(sb:StringBuilder, level:int, name:String):void
    sb.append("\e[1m") if @color
    sb.append("* [")
    if @color && level > 800
      if level > 900
        sb.append("\e[31m")
      else
        sb.append("\e[34m")
      end
    end
    sb.append(shorten(name))
    sb.append("\e[39m") if @color
    sb.append('] ')
    sb.append("\e[0m") if @color
  end

  def shorten(name:String):String
    short = String(@names[name])
    return short if short
    pieces = Arrays.asList(name.split('\.'))
    pieces.size.times do |i|
      key = pieces.subList(pieces.size - i - 1, pieces.size)
      existing = List(@inverse_names[key])
      if existing.nil? || existing == [name]
        @inverse_names[key] = [name]
        return String(@names[name] = join(key, '.'))
      else
        existing.each {|e| @names[e] = nil}
        existing.add(name) unless existing.contains(name)
        nil
      end
    end
    return name
  end

  def join(list:Iterable, sep:String):String
    sb = StringBuilder.new
    it = list.iterator
    while it.hasNext
      sb.append(it.next)
      sb.append(sep) if it.hasNext
    end
    sb.toString
  end

  def format(record):String
    sb = StringBuilder.new
    format_name(sb, record.getLevel.intValue, record.getLoggerName)
    sb.append(formatMessage(record))
    sb.append("\n")
    if record.getThrown
      sw = StringWriter.new
      pw = PrintWriter.new(sw)
      record.getThrown.printStackTrace(pw)
      pw.close
      sb.append(sw.toString)
    end
    sb.toString
  end

  def install
    logger = Logger.getLogger('org.mirah')

    return logger if logger.getHandlers.any? {|h| h.getFormatter.kind_of? MirahLogFormatter}

    handler = ConsoleHandler.new
    handler.setLevel(Level.ALL)
    handler.setFormatter(self)

    logger.addHandler(handler)
    logger.setUseParentHandlers(false)
    logger
  end
end
