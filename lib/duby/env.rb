require 'rbconfig'

module Duby
  module Env

    # Returns the system PATH_SEPARATOR environment variable value. This is used when
    # separating multiple paths in one string. If none is defined then a : (colon)
    # is returned
    def self.path_seperator
      ps = RbConfig::CONFIG['PATH_SEPARATOR']
      ps = ':' if ps.nil? || ps == ''
      ps
    end

    # Takes an array of strings and joins them using the path_separator returning
    # a single string value
    def self.encode_paths(paths)
      paths.join(path_seperator)
    end

    # Takes a single string value "paths" and returns an array of strings containing the
    # original string separated using the path_separator. An option second parameter
    # is an array that will have the strings appended to it. If the optional array parameter
    # is supplied it is returned as the result
    def self.decode_paths(paths, dest = nil)
      result = dest ? dest : []
      paths.split(path_seperator).each do |path|
        result << path
      end
      result
    end
  end
end
