package org.foo;

public class InnerInterfaceClass {
  public static interface InnerInterface {
    public void foo(Object a);
  }
  
  public static void forward(Object param,InnerInterface i) {
    i.foo(param);
  }
}

