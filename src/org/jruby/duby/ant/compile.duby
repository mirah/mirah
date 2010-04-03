import org.apache.tools.ant.Task
import org.jruby.duby.DubyCommand
import java.util.ArrayList

class Compile < Task
  def initialize
    @src = ''
    @target = ''
    @classpath = ''
  end

  def execute; returns void
    handleOutput("compiling Duby source in #{@src} to #{@target}")
    DubyCommand.compile(['-d', @target, '-c', @classpath, @src])
  end

  def setSrc(a:String)
    @src = a
    return
  end

  def setTarget(a:String)
    @target = a
    return
  end

  def setClasspath(a:String)
    @classpath = a
    return
  end
end