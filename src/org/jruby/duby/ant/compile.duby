import org.apache.tools.ant.Task
import org.apache.tools.ant.types.Path
import java.io.File
import org.jruby.duby.DubyCommand
import java.util.ArrayList

class Compile < Task
  def initialize
    @src = '.'
    @target = '.'
    @classpath = Path.new(getProject)
    @dir = '.'
  end

  def execute; returns void
    handleOutput("compiling Duby source in #{@src} to #{@target}")
    DubyCommand.compile(
        ['-d', @target, '--cd', @dir, '-c', @classpath.toString, @src])
  end

  def setSrc(a:File)
    @src = a.getAbsolutePath
    return
  end

  def setDestdir(a:File)
    @target = a.getAbsolutePath
    return
  end

  def setDir(a:File)
    @dir = a.getAbsolutePath
    return
  end

  def setClasspath(s:Path)
    createClasspath.append(s)
    return
  end

  def createClasspath
    @classpath.createPath
  end
end