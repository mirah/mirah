package org.mirah.jvm.compiler;

import java.lang.annotation.*;

// This is currently meant to be used internally by the compiler,
// not in user code.
@Retention(RetentionPolicy.SOURCE)
public @interface Cleaned {
}