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

import javax.servlet.http.HttpServlet
import javax.servlet.http.HttpServletRequest
import javax.servlet.Filter
import com.google.appengine.ext.duby.db.Model
import com.google.appengine.api.datastore.Text
import java.util.Date
import org.pegdown.PegDownProcessorStub
import com.google.appengine.api.users.UserServiceFactory
import com.google.appengine.api.users.User
import java.util.ArrayList
import java.util.List

class Page < Model
  property 'title', String
  property 'body', Text
  property 'userid', String
  property 'user', User
  property 'nickname', String
  property 'comment', String
  property 'created', Date
  property 'version', Long
  property 'locked', Boolean
end

class Helper < HttpServlet
  def markdown(text:String)
    return "" unless text
    flags = 0x5ff
    if @allow_html
      flags |= 0x200 unless @allow_html
      @html_markdown ||= PegDownProcessorStub.new(flags)
      @html_markdown.markdownToHtml(text)
    else
      @nohtml_markdown ||= PegDownProcessorStub.new(flags)
      @nohtml_markdown.markdownToHtml(text)
    end
  end

  def html=(enabled:boolean)
    @allow_html = enabled
  end

  def page_name(name:String)
    if name.nil?
      return "Main"
    else
      name = name.replaceAll("\\W", "")
    end
    if name.equals("")
      "Main"
    else
      name
    end
  end

  def h(text:String)
    return "" unless text
    text = text.replace("&", "&amp;")
    text = text.replace("<", "&lt;")
    text = text.replace(">", "&gt;")
    text = text.replace("\"", "&quot;")
    text.replace("'", "&#39;")
  end

  def h(o:Object)
    h(o.toString)
  end

  def_edb(layout, 'org/mirah/wiki/layout.eduby.html')

  def with_layout(content:String)
    @content = content
    layout
  end

  def title
    @title
  end

  def title=(title:String)
    @title = title
  end

  def users
    @users ||= UserServiceFactory.getUserService()
  end

  macro def admin?
    quote { users.isUserAdmin }
  end

  def user
    users.getCurrentUser
  end

  def nickname
    user.getNickname.replaceAll('@.*', '')
  end

  def extra_links
    @links ||= ArrayList.new
  end

  def url
    '/'
  end
end

class ViewPage < Helper
  def_edb(view, 'org/mirah/wiki/view.eduby.html')

  def doGet(request, response)
    @url = request.getRequestURI
    self.title = @name = page_name(request.getPathInfo)
    canonical = "/" + @name
    unless canonical.equals(request.getPathInfo)
      response.sendRedirect(canonical)
      return
    end

    @page = Page.get(@name)
    self.html = @page.locked if @page
    response.getWriter.write(with_layout(view))
  end

  def url
    @url
  end

  def extra_links
    links = ArrayList.new
    if @page
      can_edit = admin?
      can_edit = true unless @page.locked
      if can_edit
        links.add(["Edit", "/edit/#{@page.title}"])
      end
    end
    links.add(["New Page", "javascript:void(newPage())"])
    links
  end
end

import java.util.logging.Logger

class EditPage < Helper
  def_edb(edit, 'org/mirah/wiki/edit.eduby.html')
  def_edb(error, 'org/mirah/wiki/error.eduby.html')

  def logger
    @logger ||= Logger.getLogger("EditPage")
  end

  def render(content:String)
    @response.setContentType("text/html; charset=utf-8")
    @response.getWriter.write(with_layout(content))
  end

  def url
    @url
  end

  def doGet(request, response)
    @url = request.getRequestURI
    @response = response
    @error = String(nil)
    @name = page_name(request.getPathInfo)
    @page = Page.get(@name)
    if @page && @page.locked
      unless admin?
        @error = "You are not authorized to edit this page"
        response.setStatus(403)
        render(error)
        return
      end
    end
    render(edit)
  end

  def doPost(_request, _response)
    @error = nil
    @response = _response
    @url = _request.getRequestURI

    # TODO scope inside blocks is not quite right
    this = self
    request = _request
    response = _response
    is_admin = admin?

    name = page_name(request.getPathInfo)

    begin
      edit_version = Long.parseLong(String(request.getParameter("version")))
    rescue NumberFormatException
      response.sendError(
          400, "Invalid version '#{request.getParameter("version")}'")
      return
    end

    Model.transaction do
      orig_page = Page.get(name)
      current_version = orig_page ? orig_page.version : long(0)
      if current_version != edit_version
        @error = <<EOS
Version conflict. You are trying to edit version #{edit_version}, but
the current version is #{current_version}.
EOS
        @page = orig_page
        @name = name
        response.setStatus(409)
        this.render(this.edit)
        return
      end
      if orig_page && orig_page.locked
        unless is_admin
          @error = "You are not authorized to edit this page"
          response.setStatus(403)
          this.render(this.error)
          return
        end
      end

      this.save_old_version(orig_page) if orig_page

      if orig_page
        page = orig_page
        page.version = page.version + 1
      else
        page = Page.new(name)
        page.title = name
        page.version = 1
      end

      locked = is_admin && "locked".equals(request.getParameter("locked"))
      page.body = String(request.getParameter("body"))
      page.nickname = String(request.getParameter("nickname"))
      page.comment = String(request.getParameter("comment"))
      page.user = this.user
      page.userid = this.user.getUserId
      page.created = Date.new
      page.locked = locked
      page.save
      response.sendRedirect("/wiki/" + name)
    end
  end

  def save_old_version(orig_page:Page)
    old_version = Page.new(orig_page)
    old_version.title = orig_page.title
    old_version.body = orig_page.body
    old_version.userid = orig_page.userid
    old_version.user = orig_page.user
    old_version.nickname = orig_page.nickname
    old_version.comment = orig_page.comment
    old_version.created = orig_page.created
    old_version.version = orig_page.version
    old_version.locked = orig_page.locked
    old_version.save
  end
end

import test.MirahParser
import jmeta.BaseParser
class MirahParserPage < Helper
  def_edb(render, 'org/mirah/wiki/parser.eduby.html')

  def initialize
    self.title = "Mirah Parser Test"
  end

  def doGet(request, response)
    doPost(request, response)
  end

  def doPost(request, response)
    @code = String(request.getParameter("code")) || "puts 'Hello, world!'"
    parser = MirahParser.new
    begin
      @parsed = BaseParser.print_r(parser.parse(@code))
    rescue => ex
      @parsed = ex.getMessage
    end
    response.getWriter.write(with_layout(render))
  end
end

class FederatedLogin < Helper
  def doGet(request, response)
    provider = request.getPathInfo
    if provider && provider.length > 1
      provider = provider.substring(1)
    else
      provider = 'www.google.com/accounts/o8/id'
    end
    continue = String(request.getParameter('continue')) || '/'
    url = users.createLoginURL(continue, nil, provider, nil)
    response.sendRedirect(url)
  end
end

class LoginRequired < Helper
  def doGet(request, response)
    # This should be a page allowing people to select an OpenID provider.
    # But I'm lazy so I'll just force them to use gmail...
    continue = String(request.getParameter('continue'))
    url = users.createLoginURL(continue, nil, 'www.google.com/accounts/o8/id', nil)
    response.sendRedirect(url)
  end
end

class MainFilter; implements Filter
  def init(arg); end
  def destroy; end
  def doFilter(request, response, filters)
    if "/".equals(HttpServletRequest(request).getRequestURI)
      request.getRequestDispatcher('/wiki/Main').forward(request, response)
      nil
    else
      filters.doFilter(request, response)
      nil
    end
  end
end
