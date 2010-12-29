/*
 Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
 All contributing project authors may be found in the NOTICE file.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/
package org.mirah;

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
