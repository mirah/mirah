require 'appengine-rack'
require 'appengine-rack/java'

# TODO: Fill in your app id
AppEngine::Rack.app.configure(:application => '', :version => '1')

run JavaServlet.new('com.ribrdb.DubyApp')