module Mirah
  module Logging
    java_import 'java.util.logging.Logger'
    java_import 'java.util.logging.Formatter'
    java_import 'java.util.logging.ConsoleHandler'
    java_import 'java.util.logging.Level'

    MirahLogger = Logger.getLogger('org.mirah')
    MirahHandler = ConsoleHandler.new
    MirahLogger.addHandler(MirahHandler)
    MirahLogger.use_parent_handlers = false
    MirahHandler.level = Level::ALL
    
    class LogFormatter < Formatter
      def initialize(use_color=true)
        @color = use_color
        @names = {}
        @inverse_names = {}
      end
      
      def format_name(sb, level, name)
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
      
      def shorten(name)
        short = @names[name]
        return short if short
        pieces = name.split('.')
        pieces.size.times do |i|
          key = pieces[-i - 1, i + 1]
          existing = @inverse_names[key]
          if existing.nil? || existing == [name]
            @inverse_names[key] = [name]
            return @names[name] = key.join('.')
          else
            existing.each {|i| @names[i] = nil}
            existing << name unless existing.include?(name)
          end
        end
        return name
      end
      
      def format(record)
        sb = java.lang.StringBuilder.new
        format_name(sb, record.level.int_value, record.logger_name)
        sb.append(formatMessage(record))
        sb.append("\n")
        if record.thrown
          sw = java.io.StringWriter.new
          pw = java.io.PrintWriter.new(sw)
          record.thrown.printStackTrace(pw)
          pw.close
          sb.append(sw.toString)
        end
        sb.toString
      end
    end
    
    MirahHandler.formatter = LogFormatter.new

    module Logged
      VLEVELS = [Level::CONFIG, Level::FINE, Level::FINER, Level::FINEST]
      def logger
        @logger ||= java.util.logging.Logger.getLogger(logger_name)
      end
      
      def logger_name
        name = self.class.name.sub(/^Mirah::/, '').gsub('::', '.')
        "org.mirah.ruby.#{name}"
      end
      
      def error(*args)
        logger.log(Level::SEVERE, *args)
      end
      
      def warning(*args)
        logger.log(Level::WARNING, *args)
      end
      
      def info(*args)
        logger.log(Level::INFO, *args)
      end
      
      def log(*args)
        vlog(1, *args)
      end

      def logging?(level=Level::FINE)
        level = VLEVELS[level] unless level.kind_of?(Level)
        logger.isLoggable(level)
      end

      def vlog(level, *args)
        logger.log(VLEVELS[level], *args)
      end
    end
  end
end