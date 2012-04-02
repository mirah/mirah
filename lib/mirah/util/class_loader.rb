module Mirah
  module Util
    
    ClassLoader = Java::OrgMirah::MirahClassLoader

    # converts string to a java string w/ binary encoding
    # might be able to avoid this in 1.9 mode
    def ClassLoader.binary_string string
        java.lang.String.new string.to_java_bytes, "ISO-8859-1"
    end    
  end
end
