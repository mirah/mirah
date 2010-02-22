import javax.servlet.http.HttpServlet
import com.google.appengine.ext.duby.db.Model

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
    post.body = Text.new(request.getParameter('body'))
    post.save
    doGet(request, response)
  end

end