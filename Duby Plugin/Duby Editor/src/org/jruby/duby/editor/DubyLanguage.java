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
package org.mirah.editor;

import org.netbeans.api.lexer.Language;
import org.netbeans.modules.csl.api.Formatter;
import org.netbeans.modules.csl.api.KeystrokeHandler;
import org.netbeans.modules.csl.spi.DefaultLanguageConfig;
import org.netbeans.modules.parsing.spi.Parser;
import org.netbeans.modules.ruby.RubyFormatter;
import org.netbeans.modules.ruby.RubyKeystrokeHandler;
import org.netbeans.modules.ruby.RubyParser;
import org.netbeans.modules.ruby.lexer.RubyTokenId;

/**
 *
 * @author ribrdb
 */
public class DubyLanguage extends DefaultLanguageConfig {

    @Override
    public Language getLexerLanguage() {
        return RubyTokenId.language();
    }

    @Override
    public String getDisplayName() {
        return "Duby";
    }

    @Override
    public Formatter getFormatter() {
        return new RubyFormatter();
    }

    @Override
    public KeystrokeHandler getKeystrokeHandler() {
        return new RubyKeystrokeHandler();
    }

    @Override
    public Parser getParser() {
        return new DubyParser();
    }
}
