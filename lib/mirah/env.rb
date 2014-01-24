# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
# All contributing project authors may be found in the NOTICE file.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rbconfig'

module Mirah
  module Env

    # Returns the system PATH_SEPARATOR environment variable value. This is used when
    # separating multiple paths in one string. If none is defined then a : (colon)
    # is returned
    def self.path_separator
      File::PATH_SEPARATOR
    end

    # Takes an array of strings and joins them using the path_separator returning
    # a single string value
    def self.encode_paths(paths)
      paths.join(path_separator)
    end

    # Takes a single string value "paths" and returns an array of strings containing the
    # original string separated using the path_separator. An option second parameter
    # is an array that will have the strings appended to it. If the optional array parameter
    # is supplied it is returned as the result
    def self.decode_paths(paths, dest = nil)
      result = dest ? dest : []
      paths.split(path_separator).each do |path|
        result << path
      end
      result
    end

    def self.make_urls classpath
      decode_paths(classpath).map do |filename|
        java.io.File.new(filename).to_uri.to_url
      end.to_java(java.net.URL)
    end
  end
end
