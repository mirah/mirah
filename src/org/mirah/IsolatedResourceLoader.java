package org.mirah;

import java.lang.ClassLoader;
import java.net.URLClassLoader;
import java.net.URL;

// Isolates resource lookup from the parent and
// default class loaders.
public class IsolatedResourceLoader extends URLClassLoader {

    // just in case, we make the parent nil,
    // so if something tries to ask it for something,
    // it'll blow up.
    public IsolatedResourceLoader(URL[] urls) {
        super(urls, (ClassLoader) null);
    }

    // Unlike ClassLoader.getResource, which checks the parent class loader for the resource first,
    // this implementation only looks in the list of urls given to it.
    @Override
    public URL getResource(String name) {
        return findResource(name);
    }
}

/*
MIRAH src


import java.lang.ClassLoader
import java.net.URLClassLoader
import java.net.URL

# Isolates resource lookup from the parent and
# default class loaders.
class IsolatedResourceLoader < URLClassLoader

  # just in case, we make the parent nil,
  # so if something tries to ask it for something,
  # it'll blow up.
  def initialize(urls:URL[])
    super(urls, ClassLoader(nil))
  end

  # Unlike ClassLoader.getResource, which checks the parent class loader for the resource first,
  # this implementation only looks in the list of urls given to it.
  def getResource(name)
    findResource(name)
  end
end
*/
