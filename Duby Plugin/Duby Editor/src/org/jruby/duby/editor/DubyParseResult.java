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

import java.util.ArrayList;
import java.util.List;
import org.mirah.ParseError;
import org.mirah.ParseResult;
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
