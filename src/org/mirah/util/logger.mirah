package org.mirah.util

import java.util.logging.Level
import java.util.logging.Handler

#
# Nearly transparent optimized implementation of java.util.logging.Logger.
#
# This class serves as pseudo-class for macro calls. The macros are named after the methods of java.util.logging.Logger.
# Each macro calls the actual logger only if the log message is loggable anyway.
# Hence, the log message is prevented from being constructed in case the message won't be logged anyway. This minimizes the logging overhead, and
# is more beautiful than explicitly calling @@log.isLoggable() each time @@log.log is to be called.
#
class Logger
  attr_reader internal_logger:java.util.logging.Logger
  
  def initialize(internal_logger:Object) # old compiler cannot handle def initialize(internal_logger:java.util.logging.Logger) 
    @internal_logger = java::util::logging::Logger(internal_logger)
  end

  macro def finest(arg)
    javalogger = "#{gensym}_javalogger"
    quote do
      `javalogger` = `@call.target`.internal_logger
      if `javalogger`.isLoggable(java::util::logging::Level.FINEST)
        `javalogger`.finest(`arg`)
      end
    end
  end

  macro def finer(arg)
    javalogger = gensym 
    quote do
      `javalogger` = `@call.target`.internal_logger
      if `javalogger`.isLoggable(java::util::logging::Level.FINER)
        `javalogger`.finer(`arg`)
      end
    end
  end
    
  macro def fine(arg)
    javalogger = gensym 
    quote do
      `javalogger` = `@call.target`.internal_logger
      if `javalogger`.isLoggable(java::util::logging::Level.FINE)
        `javalogger`.fine(`arg`)
      end
    end
  end
    
  macro def info(arg)
    javalogger = gensym 
    quote do
      `javalogger` = `@call.target`.internal_logger
      if `javalogger`.isLoggable(java::util::logging::Level.INFO)
        `javalogger`.info(`arg`)
      end
    end
  end
    
  macro def warning(arg)
    javalogger = gensym 
    quote do
      `javalogger` = `@call.target`.internal_logger
      if `javalogger`.isLoggable(java::util::logging::Level.WARNING)
        `javalogger`.warning(`arg`)
      end
    end
  end
    
  macro def severe(arg)
    javalogger = gensym 
    quote do
      `javalogger` = `@call.target`.internal_logger
      if `javalogger`.isLoggable(java::util::logging::Level.SEVERE)
        `javalogger`.severe(`arg`)
      end
    end
  end
    
  macro def entering(arg0,arg1,arg2)
    javalogger = gensym 
    quote do
      `javalogger` = `@call.target`.internal_logger
      if `javalogger`.isLoggable(java::util::logging::Level.FINER)
        `javalogger`.entering(`arg0`,`arg1`,`arg2`)
      end
    end
  end
    
  macro def log(level, arg1)
    javalogger = "#{gensym}_javalogger"
    levellocal = "#{gensym}_levellocal"
    quote do
      `javalogger` = `@call.target`.internal_logger
      `levellocal` = `level`
      if `javalogger`.isLoggable(`levellocal`)
        `javalogger`.log(`levellocal`,`arg1`)
      end
    end
  end
    
  macro def log(level,arg1,arg2)
    javalogger = gensym
    levellocal = gensym
    quote do
      `javalogger` = `@call.target`.internal_logger
      `levellocal` = `level`
      if `javalogger`.isLoggable(`level`)
        `javalogger`.log(`level`,`arg1`,`arg2`)
      end
    end
  end
    
  def setLevel(level:Level)
    internal_logger.setLevel(level)
  end
  
  def isLoggable(level:Level)
    internal_logger.isLoggable(level)
  end

  def addHandler(handler:Handler)
    internal_logger.addHandler(handler)
  end
  
  macro def getHandlers()
    quote do
      `@call.target`.internal_logger.getHandlers()
    end
  end

  macro def setUseParentHandlers(arg0)
    quote do
      `@call.target`.internal_logger.setUseParentHandlers(`arg0`)
    end
  end

  def self.getLogger(name:String)
    self.new(java::util::logging::Logger.getLogger(name))
  end
end
