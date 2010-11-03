require 'jruby/synchronized'
require 'thread'

module Duby
  module Threads
    class SynchronizedArray < Array
      include JRuby::Synchronized
    end

    class SynchronizedHash < Hash
      include JRuby::Synchronized
    end

    class Executor
      java_import 'java.util.concurrent.Executors'

      def initialize(executor=nil)
        @executor = executor ||
            Executors.new_cached_thread_pool(DaemonThreadFactory.new)
      end

      class DaemonThreadFactory
        java_import 'java.util.concurrent.ThreadFactory'
        java_import 'java.lang.Thread'
        include ThreadFactory

        def newThread(runnable)
          thread = Thread.new(runnable)
          thread.setDaemon(true)
          thread
        end
      end

      class MirahTask
        java_import 'java.util.concurrent.Callable'
        include Callable

        def initialize(factory=nil, &block)
          @factory = factory || Duby::AST.type_factory
          @block = block
        end

        def call
          Duby::AST.type_factory = @factory
          @block.call
        end
      end

      def each(list)
        tasks = list.map do |x|
          MirahTask.new do
            yield x
          end
        end
        futures = @executor.invoke_all(tasks)
        futures.map {|x| x.get}
      end

      def execute(&block)
        each([nil], &block)[0]
      end
    end

  end
end