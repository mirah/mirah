/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package org.jruby.duby.editor;

import java.io.StringReader;
import java.util.ArrayList;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.swing.event.ChangeListener;
import org.jruby.Ruby;
import org.jruby.RubyInstanceConfig;
import org.jruby.duby.DubyCompiler;
import org.jruby.duby.ParseResult;
import org.jruby.exceptions.RaiseException;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jrubyparser.CompatVersion;
import org.jrubyparser.ast.Node;
import org.jrubyparser.lexer.LexerSource;
import org.jrubyparser.lexer.SyntaxException;
import org.jrubyparser.parser.ParserConfiguration;
import org.jrubyparser.parser.Ruby18Parser;
import org.netbeans.modules.parsing.api.Snapshot;
import org.netbeans.modules.parsing.api.Task;
import org.netbeans.modules.parsing.spi.ParseException;
import org.netbeans.modules.parsing.spi.Parser;
import org.netbeans.modules.parsing.spi.SourceModificationEvent;
import org.openide.filesystems.FileObject;

/**
 *
 * @author ribrdb
 */
class DubyParser extends Parser {
    private static final Logger logger = Logger.getLogger(DubyParser.class.getName());
    private static final Ruby runtime;
    private static final DubyCompiler parser;

    static {
        System.setProperty("jruby.duby.enabled", "true");
        RubyInstanceConfig config = new RubyInstanceConfig();
        config.processArguments(new String[]{"-d"});
        runtime = JavaEmbedUtils.initialize(new ArrayList());
        parser = (DubyCompiler) JavaEmbedUtils.newRuntimeAdapter().eval(
                runtime, "require 'mirah/nbcompiler';Duby::NbCompiler.new").toJava(DubyCompiler.class);
    }

    Result result;

    public DubyParser() {
    }

    private ParseResult parse(String text) {
        synchronized (runtime) {
            return parser.parse(text);
        }
    }

    @Override
    public void parse(Snapshot snapshot, Task arg1, SourceModificationEvent arg2) throws ParseException {
        try {
            result = new DubyParseResult(snapshot, parse(new StringBuilder(snapshot.getText()).toString()));
        } catch (RaiseException ex) {
            if (ex.getCause() instanceof SyntaxException) {
                result = new DubyParseResult(snapshot, (SyntaxException)ex.getCause());
            } else if (ex.getCause() != null) {
                logger.log(Level.SEVERE, null, ex.getCause());
            } else {
                logger.log(Level.SEVERE, null, ex);
            }
        } catch (SyntaxException ex) {
            result = new DubyParseResult(snapshot, ex);
        }
    }

    @Override
    public Result getResult(Task arg0) throws ParseException {
        return result;
    }

    @Override
    public void cancel() {

    }

    @Override
    public void addChangeListener(ChangeListener arg0) {

    }

    @Override
    public void removeChangeListener(ChangeListener arg0) {

    }

}
