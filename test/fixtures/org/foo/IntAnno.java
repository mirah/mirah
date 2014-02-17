package org.foo;

import java.lang.annotation.*;

@Retention(RetentionPolicy.RUNTIME)
public @interface IntAnno {
  String name();
  int value();
}