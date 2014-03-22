package org.mirah.util

import java.util.ArrayList
import java.util.List

interface OptionCallback
  def run(value:String):void; end
end

class CommandLineOption
  def initialize(names:List, help:String, cb:Runnable)
    @names = names
    @help = help
    @callback = cb
  end

  def initialize(names:List, placeholder:String, help:String, cb:OptionCallback)
    @names = names
    @help = help
    @option_callback = cb
    @placeholder = placeholder
  end

  attr_reader names:List, help:String, callback:Runnable
  attr_reader placeholder:String, option_callback:OptionCallback
end

class OptionParser
  def initialize(usage:String)
    @usage = usage
    @options = ArrayList.new
    @flagMap = {}
  end

  def addFlag(names:List, help:String, cb:Runnable):void
    add(CommandLineOption.new(names, help, cb))
  end

  def addFlag(names:List, placeholder:String, help:String, cb:OptionCallback):void
    add(CommandLineOption.new(names, placeholder, help, cb))
  end

  def add(flag:CommandLineOption):void
    @options.add(flag)
    flag.names.each do |n|
      @flagMap[n] = flag
    end
  end

  def parse(options:String[]):List
    options_finished = false
    filenames = ArrayList.new
    value_parser = OptionCallback(nil)
    options.each do |arg|
      if options_finished
        filenames.add(arg)
      elsif value_parser
        value_parser.run(arg)
        value_parser = nil
      elsif "--".equals(arg)
        options_finished = true
      elsif arg.startsWith("--")
        value_parser = parseOption(arg.substring(2), "--")
      elsif arg.startsWith("-")
        value_parser = parseOption(arg.substring(1), "-")
      else
        filenames.add(arg)
      end
    end
    filenames
  end

  def parseOption(arg:String, dashes:String)
    option = CommandLineOption(@flagMap[arg])
    if option.nil?
      raise IllegalArgumentException, "Unrecognized flag: #{dashes}#{arg}"
    end
    if option.option_callback
      option.option_callback
    else
      option.callback.run
      nil
    end
  end

  def printUsage
    puts @usage
    @options.each do |flag:CommandLineOption|
      first_name = true
      flag.names.each do |n:String|
        unless first_name
          print ", "
        end
        first_name = false
        if n.length == 1
          print "-#{n}"
        else
          print "--#{n}"
        end
        if flag.placeholder
          print " "
          print flag.placeholder
        end
      end
      puts ""
      print "\t"
      puts flag.help
      nil
    end
  end
end