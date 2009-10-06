package org.jruby.duby.editor;

import java.util.ArrayList;
import java.util.List;
import org.jruby.duby.ParseError;
import org.jruby.duby.ParseResult;
import org.jruby.runtime.builtin.IRubyObject;
import org.jrubyparser.SourcePosition;
import org.jrubyparser.lexer.SyntaxException;
import org.netbeans.modules.csl.api.Error;
import org.netbeans.modules.csl.api.Severity;
import org.netbeans.modules.csl.spi.ParserResult;
import org.netbeans.modules.parsing.api.Snapshot;
import org.openide.filesystems.FileObject;

/**
 *
 * @author ribrdb
 */
class DubyParseResult extends ParserResult {
    class DubyParseError implements Error {
        private FileObject file;
        private String message;
        private int start;
        private int end;

        public DubyParseError(FileObject file, String message, SourcePosition position) {
            this.file = file;
            this.message = message;
            this.start = position.getStartOffset();
            this.end = position.getEndOffset() + 1;
        }

        public String getDisplayName() {
            return message;
        }

        public String getDescription() {
            return message;
        }

        public String getKey() {
            return message;
        }

        public FileObject getFile() {
            return file;
        }

        public int getStartPosition() {
            return start;
        }

        public int getEndPosition() {
            return end;
        }

        public boolean isLineError() {
            return false;
        }

        public Severity getSeverity() {
            return Severity.ERROR;
        }

        public Object[] getParameters() {
            return null;
        }

    }

    IRubyObject ast;
    ArrayList<DubyParseError> errors = new ArrayList<DubyParseError>();

    DubyParseResult(Snapshot snapshot, SyntaxException ex) {
        super(snapshot);
        FileObject file = snapshot.getSource().getFileObject();
        errors.add(new DubyParseError(file, ex.getMessage(), ex.getPosition()));
    }

    DubyParseResult(Snapshot snapshot, ParseResult result) {
        super(snapshot);
        this.ast = (IRubyObject)result.ast();
        FileObject file = snapshot.getSource().getFileObject();
        for (ParseError error : result.errors()) {
            errors.add(new DubyParseError(file, error.message(), error.position()));
        }
    }

    @Override
    protected void invalidate() {
        ast = null;
    }

    @Override
    public List<? extends Error> getDiagnostics() {
        return errors;
    }

}
