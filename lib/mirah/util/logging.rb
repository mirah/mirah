module Mirah
  module Logging
    java_import 'java.util.logging.Logger'
    java_import 'java.util.logging.Formatter'
    java_import 'java.util.logging.ConsoleHandler'
    java_import 'java.util.logging.Level'

    MirahLogger = Logger.getLogger('org.mirah')

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
