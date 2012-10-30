package org.mirah.macros.anno;

import java.lang.annotation.*;

@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface MacroDef {
    // TODO(ribrdb) Should this include modifiers?
    // What about restrictions on where it applies (e.g. only as a FunctionalCall, only in a ClassDefinition)
    String name();
    MacroArgs arguments() default @MacroArgs;
	boolean isStatic() default false;
}
