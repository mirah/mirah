package org.mirah.macros.anno;

import java.lang.annotation.*;

@Retention(RetentionPolicy.CLASS)
@Target(ElementType.TYPE)
public @interface Extensions {
    // TODO: The bootstrap mirah doesn't support Class annotation values. This is an array of class names.
    String[] macros();
}
