/*
 *
 * Copyright (c) 2015 The Mirah project authors. All Rights Reserved.
 * All contributing project authors may be found in the NOTICE file.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

package org.mirah.util;

/**
 * Contains comparison methods for the compiler to use so that the === and == intermediate state
 * won't cause issues compiling the compiler.
**/
public class Comparisons {
    /**
     * does a == comparison of objects so that the compiler can use it w/o worrying about == vs ===
     */
    public static boolean areSame(Object a, Object b) {
      return a == b;
    }

    /**
     * does a != comparison of objects so that the compiler can use it w/o worrying about == vs ===
     */
    public static boolean areNotSame(Object a, Object b) {
        return a != b;
    }


    /**
     * does a == comparison of ints so that the compiler can use it w/o worrying about == vs ===
     */
    public static boolean areSame(int a, int b) {
      return a == b;
    }

    /**
     * does a != comparison of ints so that the compiler can use it w/o worrying about == vs ===
     */
    public static boolean areNotSame(int a, int b) {
        return a != b;
    }
}