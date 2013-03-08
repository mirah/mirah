package org.mirah.jvm.types;

import java.lang.annotation.*;

// This is currently meant to be used internally by the compiler,
// not in user code.
@Retention(RetentionPolicy.SOURCE)
public @interface Modifiers {
  MemberAccess access();
  Flags[] flags() default {};
}