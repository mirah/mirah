import java.lang.annotation.*;
@Retention(RetentionPolicy.CLASS)
@Target(ElementType.TYPE)
public @interface MacroDef {
    // TODO(ribrdb) Should this include modifiers?
    // What about restrictions on where it applies (e.g. only as a FunctionalCall, only in a ClassDefinition)
    String name();
    MacroArgs arguments() default @MacroArgs;
    
    // Bootstrap compiler doesn't support nested annotations.
    // Normal macros should use arguments not signature.
    @Deprecated
    String signature() default "";
}