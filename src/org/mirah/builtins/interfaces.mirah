package org.mirah.builtins

interface ExtensionsService
    # @param - macro_holder - a class holding ExtensionsRegistration annotation
    def macro_registration(macro_holder:Class):void;end
end

# registration of macro extensions via java service SPI 
# put implementation class name in (META-INF/services/org.mirah.macros.ExtensionsProvider
interface ExtensionsProvider 
    def register(service:ExtensionsService):void;end
end