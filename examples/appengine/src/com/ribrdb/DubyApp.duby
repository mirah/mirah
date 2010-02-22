import javax.servlet.http.HttpServlet
import com.google.appengine.ext.duby.db.Model
import java.util.HashMap
import java.util.regex.Pattern
import java.util.logging.Logger

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
    @logger = Logger.getLogger("DubyApp")
    @escape_pattern = Pattern.compile("[<>&'\"]")
    @escaped = HashMap.new
    @escaped.put("<", "&lt;")
    @escaped.put(">", "&gt;")
    @escaped.put("&", "&amp;")
    @escaped.put("\"", "&quot;")
    @escaped.put("'", "&#39;")
  end

  def h(text:String)
    @logger.info("h(" + text + ")")
    matcher = @escape_pattern.matcher(text)
    buffer = StringBuffer.new
    while matcher.find
      replacement = String(@escaped.get(matcher.group))
      @logger.info(matcher.group + " -> " + replacement)
      matcher.appendReplacement(buffer, replacement)
    end
    matcher.appendTail(buffer)
    @logger.info("result: " + buffer.toString)
    return buffer.toString
  end

  def h(o:Object)
    return "" unless o
    h(o.toString)
  end
end