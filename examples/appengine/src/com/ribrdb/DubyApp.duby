import javax.servlet.http.HttpServlet
import com.google.appengine.ext.duby.db.Model
import java.util.HashMap
import java.util.regex.Pattern

class Post < Model
  def initialize; end

  property title, String
  property body, Text
end

class DubyApp < HttpServlet
  def_edb(list, 'com/ribrdb/list.dhtml')

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