import org.apache.tools.ant.Task
import org.apache.tools.ant.types.Path
import org.apache.tools.ant.types.Reference
import java.io.File
import org.mirah.MirahCommand
import java.util.ArrayList

class Compile < Task
  def initialize
    @src = '.'
    @target = '.'
    @classpath = Path.new(getProject)
    @dir = '.'
    @bytecode = true
  end

  def execute:void
    handleOutput("compiling Duby source in #{@src} to #{@target}")
    System.err.println("project: #{getProject}")
    args = ArrayList.new(
         ['-d', @target, '--cd', @dir, '-c', @classpath.toString, @src])
    args.add(0, '--java') unless @bytecode 
    MirahCommand.compile(args)
  end

  def setSrc(a:File):void
    @src = a.getAbsolutePath
  end

  def setDestdir(a:File):void
    @target = a.getAbsolutePath
  end

  def setDir(a:File):void
    @dir = a.getAbsolutePath
  end

  def setClasspath(s:Path):void
    createClasspath.append(s)
  end

  def setClasspathref(ref:Reference):void
    System.err.println("Reference project: #{ref.getProject}")
    createClasspath.setRefid(ref)
  end

  def setBytecode(bytecode:boolean):void
    @bytecode = bytecode
  end

  def createClasspath
    @classpath.createPath
  end
end
