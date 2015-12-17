# Copyright (c) 2015 The Mirah project authors. All Rights Reserved.
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

package org.mirah.plugin

import org.mirah.util.Logger
import org.mirah.tool.MirahArguments
import mirah.lang.ast.Node
import mirah.lang.ast.Script
import java.lang.Iterable
import java.util.Map
import java.util.ServiceLoader
import org.mirah.util.Context

# initialize compiler plugins and calls them at proper compilation step
class CompilerPlugins

  def self.initialize:void
    @@log = Logger.getLogger(CompilerPlugins.class.getName)
  end

  def initialize(context:Context)

    class_loader = context[ClassLoader]
    args = context[MirahArguments]
    plugin_params = parse_plugin_params(args.plugins)
    return unless class_loader
    services = ServiceLoader.load(CompilerPlugin.class, class_loader)
    available = {}
    @plugins = plugins = []
    Iterable(services).each do |plugin: CompilerPlugin|
      available.put plugin.key, plugin
    end

    plugin_params.entrySet.each do |entry|
      plugin = CompilerPlugin(available.get entry.getKey)
      if plugin
        plugin.start(String(entry.getValue), context)
        plugins.add plugin
      else
        raise "missing plugin implementation for: " + entry.getKey
      end
    end
  end

  def on_parse(node:Node):void
    @plugins.each do |plugin:CompilerPlugin|
      plugin.on_parse Script(node)
    end
  end

  def on_infer(node:Node):void
    @plugins.each do |plugin:CompilerPlugin|
       plugin.on_infer Script(node)
    end
  end

  def on_clean(node:Node):void
    @plugins.each do |plugin:CompilerPlugin|
      plugin.on_clean Script(node)
    end
  end

  def stop:void
    @plugins.each do |plugin:CompilerPlugin|
      plugin.stop
    end
  end

  # parse plugin string pluginKeyA[:PROPERTY_A][,pluginKeyB[:PROPERTY_B]]
  # return key=>param map
  # raise runtime exception if same key parsed multiple times
  def parse_plugin_params(plugin_string:String)
    result = {}
    return result unless plugin_string
    return result if plugin_string.trim.length == 0
    plugins = plugin_string.split ','
    plugins.each do |v|
      pair = v.split ':', 2
      old_value = nil
      if pair.length == 2
        old_value = result.put pair[0], pair[1]
      else
        old_value = result.put v, ""
      end
      if old_value
        raise "multiple plugin keys: " + v + " => " + pair[0] + ":"+ old_value
      end
    end
    return result
  end
end