# This is a custom classloader impl to allow loading classes with
# interdependencies by having findClass retrieve classes as needed from the
# collection of all classes generated by the target script.
import java.security.SecureClassLoader
import java.lang.ClassLoader
import java.util.Map
import java.nio.charset.Charset

class MirahClassLoader < SecureClassLoader
  def initialize(parent:ClassLoader, class_map:Map)
    super(parent)
    @class_map = class_map
  end

  def findClass(name)
    if @class_map[name]
      bytes = String(@class_map[name]).getBytes "ISO-8859-1"
      defineClass(name, bytes, 0, bytes.length)
    else
      raise ClassNotFoundException.new(name)
    end
  end

  def loadClass(name, resolve)
    cls = findLoadedClass(name)
    if cls.nil?
      if @class_map[name]
        cls = findClass(name)
      else
        cls = super(name, false)
      end
    end

    resolveClass(cls) if resolve

    cls
  end
end