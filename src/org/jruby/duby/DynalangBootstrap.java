package org.jruby.duby;

import org.dynalang.dynalink.*;
import org.dynalang.dynalink.beans.*;
import java.dyn.*;

public class DynalangBootstrap {
    private static final DynamicLinker dynamicLinker = createDynamicLinker();
   
    private static DynamicLinker createDynamicLinker() {
        final DynamicLinkerFactory factory = new DynamicLinkerFactory();
        return factory.createLinker(); 
    }
    
    public static CallSite bootstrap(Class caller, String name, MethodType type) {
         final RelinkableCallSite callSite = new MonomorphicCallSite(caller, name, type);
         dynamicLinker.link(callSite);
       return callSite;
    }
}
