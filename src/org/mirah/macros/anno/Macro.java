import java.lang.annotation.*;
@Retention(RetentionPolicy.CLASS)
@Target({})
public @interface Macro {
    // TODO(ribrdb) Should this include modifiers?
    // What about restrictions on where it applies (e.g. only as a FunctionalCall, only in a ClassDefinition)
    String name();
    String signature();
    Class macroClass();
}