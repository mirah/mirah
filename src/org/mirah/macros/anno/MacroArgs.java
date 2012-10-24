package org.mirah.macros.anno;

import java.lang.annotation.*;

@Retention(RetentionPolicy.RUNTIME)
@Target({})
public @interface MacroArgs {
    // TODO: The bootstrap mirah doesn't support Class annotation values. These are all class names.
    String[] required() default {};
    String[] optional() default {};
    String rest() default "";
    String[] required2() default {};
    // Block should be included at the end of the list.
}
