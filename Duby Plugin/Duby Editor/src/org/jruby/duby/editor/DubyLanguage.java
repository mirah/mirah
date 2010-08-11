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
