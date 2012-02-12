module Mirah
  module Util
    
    ClassLoader = Java::OrgMirah::MirahClassLoader
    def ClassLoader.binary_string string
        java.lang.String.new string.to_java_bytes, "ISO-8859-1"
    end    
  end
end