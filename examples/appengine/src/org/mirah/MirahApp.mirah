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

import java.util.HashMap
import java.util.regex.Pattern

import javax.servlet.http.HttpServlet

import com.google.appengine.api.datastore.Text
import com.google.appengine.ext.duby.db.Model

class Post < Model
  property 'title', String
  property 'body', Text
end

class MirahApp < HttpServlet
  def_edb(list, 'org/mirah/list.dhtml')

  def doGet(request, response)
    @posts = Post.all.run
    response.getWriter.write(list)
  end

  def doPost(request, response)
    post = Post.new
    post.title = request.getParameter('title')
    post.body = request.getParameter('body')
    post.save
    doGet(request, response)
  end


  def initialize
    @escape_pattern = Pattern.compile("[<>&'\"]")
    @escaped = HashMap.new
    @escaped.put("<", "&lt;")
    @escaped.put(">", "&gt;")
    @escaped.put("&", "&amp;")
    @escaped.put("\"", "&quot;")
    @escaped.put("'", "&#39;")
  end

  def h(text:String)
    return "" unless text
    matcher = @escape_pattern.matcher(text)
    buffer = StringBuffer.new
    while matcher.find
      replacement = String(@escaped.get(matcher.group))
      matcher.appendReplacement(buffer, replacement)
    end
    matcher.appendTail(buffer)
    return buffer.toString
  end

  def h(o:Object)
    return "" unless o
    h(o.toString)
  end
end
