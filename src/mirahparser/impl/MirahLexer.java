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
package mirahparser.impl;

import java.util.ArrayList;
import java.util.EnumSet;
import java.util.LinkedList;
import java.util.ListIterator;
import java.util.logging.Logger;

import mmeta.BaseParser;
import mmeta.BaseParser.Token;
import mmeta.SyntaxError;

public class MirahLexer {

  private static final Logger logger = Logger.getLogger(MirahLexer.class.getName());

  private static final int EOF = -1;

  public interface Input {
    int pos();
    int read();
    boolean consume(char c);
    boolean consume(String s);
    void backup(int amount);
    void skip(int amount);
    boolean hasNext();
    void consumeLine();
    int peek();
    int finishCodepoint();
    CharSequence readBack(int length);
  }

  public static class StringInput implements Input {
    private int pos = 0;
    private final String string;
    private final char[] chars;
    private final int end;

    public StringInput(String string, char[] chars) {
      this.string = string;
      this.chars = chars;
      this.end = chars.length;
    }

    public int pos() {
      return pos;
    }

    public int read() {
      if (pos >= end) {
        pos = end + 1;
        return EOF;
      }
      return chars[pos++];
    }

    public boolean consume(char c) {
      if (read() == c) {
        return true;
      }
      --pos;
      return false;
    }

    public boolean consume(String s) {
      if (string.startsWith(s, pos)) {
        pos += s.length();
        return true;
      }
      return false;
    }

    public void backup(int amount) {
      pos -= amount;
    }

    public void skip(int amount) {
      if (pos < end - amount) {
        pos += amount;
      } else {
        pos = end;
      }
    }

    public boolean hasNext() {
      return pos < end;
    }

    public void consumeLine() {
      pos = string.indexOf('\n', pos);
      if (pos == -1) {
        pos = end;
      }
    }

    public int peek() {
      int result = read();
      --pos;
      return result;
    }

    public int finishCodepoint() {
      int size = 1;
      if (pos < end - 1) {
        ++pos;
        ++size;
      }
      return string.codePointAt(pos - size);
    }
    
    public CharSequence readBack(int length) {
      return string.substring(pos - length, pos);
    }
  }

  protected interface Lexer {
    Tokens skipWhitespace(MirahLexer l, Input i);
    Tokens lex(MirahLexer l, Input i);
  }
  private static abstract class BaseLexer implements Lexer {
    @Override
    public Tokens skipWhitespace(MirahLexer l, Input i) { return null; }
  }
  protected static class State implements Cloneable {
    public final Lexer lexer;
    public final State previous;
    public final boolean justOnce;
    public int braceDepth;
    public final LinkedList<Lexer> hereDocs = new LinkedList<Lexer>();

    public State(State previous, Lexer lexer, boolean justOnce) {
      this.previous = previous;
      this.lexer = lexer;
      this.justOnce = justOnce;
    }

    public State(State previous, Lexer lexer) {
      this(previous, lexer, false);
    }

    public void lbrace() {
      braceDepth += 1;
    }
    public void rbrace(MirahLexer ml) {
      braceDepth -= 1;
      if (braceDepth == -1) {
        ml.popState();
      }
    }
    
    public State clone() {
      State clone = new State(previous == null ? null : previous.clone(), lexer, justOnce);
      clone.braceDepth = braceDepth;
      clone.hereDocs.addAll(hereDocs);
      return clone;
    }
  }

  private static class CombinedState {
    private final State state;
    private final boolean isBEG;
    private final boolean isARG;
    private final boolean isEND;
    private final boolean spaceSeen;
    
    public CombinedState(MirahLexer l) {
      state = l.state.clone();
      isBEG = l.isBEG();
      isARG = l.isARG();
      isEND = l.isEND();
      spaceSeen = l.spaceSeen;
    }
  }

  private static class SStringLexer extends BaseLexer {
    private boolean isEscape(Input i) {
      return i.consume('\'') || i.consume('\\');
    }

    @Override
    public Tokens lex(MirahLexer l, Input i) {
      int c0 = i.read();
      switch (c0) {
        case '\'':
          l.popState();
          return Tokens.tSQuote;
        case '\\':
          if (isEscape(i)) {
            return Tokens.tEscape;
          }
        break;
        case '\n':
          l.noteNewline();
      }
      readRestOfString(l, i);
      return Tokens.tStringContent;
    }

    private void readRestOfString(MirahLexer l, Input i) {
      int c = 0;
      for (c = i.read(); c != EOF;c = i.read()) {
        if (c == '\n') {
          l.noteNewline();
        }
        if (c == '\'') {
          i.backup(1);
          break;
        } else if (c == '\\' && isEscape(i)) {
          i.backup(2);
          break;
        }
      }
      if ( c == EOF ){
        i.backup(1);
      }
    }
  }

  private static class DStringLexer extends BaseLexer {
    @Override
    public Tokens lex(MirahLexer l, Input i) {
      int c = i.read();
      if (isEndOfString(c)) {
        l.popState();
        return readEndOfString(i);
      }
      switch (c) {
        case '\\':
          readEscape(i);
          return Tokens.tEscape;
        case '#':
          int c2 = i.read();
          if (c2 == '{') {
            l.pushState(l.state.previous.lexer);
            return Tokens.tStrEvBegin;
          } else if (c2 == '@') {
            i.backup(1);
            l.pushForOneToken(l.state.previous.lexer);
            return Tokens.tStrEvBegin;
          }
          i.backup(1);
        break;
        case '\n':
          l.noteNewline();
        break;
      }
      readRestOfString(l, i);
      return Tokens.tStringContent;
    }
    public Tokens readEndOfString(Input i) {
      return Tokens.tDQuote;
    }
    public boolean isEndOfString(int c) {
      return c == '"';
    }
    private void readEscape(Input i) {
      int c = i.read();
      switch (c) {
        case 'x':
          i.skip(2);
          return;
        case 'u':
          i.skip(4);
          return;
        case 'U':
          i.skip(8);
          return;
        case '0': case '1': case '2': case '3': case '4': case '5': case '6': case '7':
          int c1 = i.read();
          int c2 = i.read();
          if (c1 >= '0' && c1 <= '7' && c2 >= '0' && c2 <= '7') {
            return;
          }
          i.backup(2);
        default:
          if (c >= 0xD800 && c <= 0xDFFF) {
            i.skip(1);
          }
      }
    }

    private void readRestOfString(MirahLexer l, Input i) {
      int c = 0;
      for (c = i.read(); c != EOF; c = i.read()) {
        if (isEndOfString(c)) {
          i.backup(1);
          break;
        } else if (c == '#') {
          int c2 = i.read();
          if (c2 == '{' || c2 == '@') {
            i.backup(2);
            break;
          } else {
            i.backup(1);
          }
        } else if (c == '\\') {
          i.backup(1);
          break;
        } else if (c == '\n') {
          l.noteNewline();
        }
      }
      if ( c == EOF ){
        i.backup(1);
      }
    }
  }

  private static class RegexLexer extends DStringLexer {
    @Override
    public boolean isEndOfString(int c) {
      return c == '/';
    }

    @Override
    public Tokens readEndOfString(Input i) {
      for (int c = i.read(); c != EOF; c = i.read()) {
        if (!Character.isLetter(c)){
          break;
        }
      }
      i.backup(1);
      return Tokens.tRegexEnd;
    }
  }

  private static class HereDocLexer extends BaseLexer {
    private final String marker;
    private final boolean allowIndented;
    private final boolean allowStrEv;

    public HereDocLexer(String marker, boolean allowIndented, boolean allowStrEv) {
      this.marker = marker;
      this.allowIndented = allowIndented;
      this.allowStrEv = allowStrEv;
    }

    @Override
    public Tokens lex(MirahLexer l, Input i) {
      if (readMarker(i, true)) {
        l.popState();
        return Tokens.tHereDocEnd;
      }
      if (allowStrEv && i.consume('#')) {
        if (i.consume('{') || i.consume('@')) {
          return readStrEv(l, i);
        }
      }
      for (int c = i.read();c != EOF; c = i.read()) {
        if (c == '\n') {
          if (readMarker(i, false)) {
            return Tokens.tStringContent;
          }
        } else if (allowStrEv && c == '#') {
          if (i.consume('{') || i.consume('@')) {
            i.backup(2);
            return Tokens.tStringContent;
          }
        }
      }
      i.backup(1);
      return Tokens.tStringContent;
    }

    private boolean readMarker(Input i, boolean consume) {
      int size = 0;
      int c = i.read();
      if (allowIndented) {
        while (" \t\r\f\u000b".indexOf(c) != -1) {
          size += 1;
          c = i.read();
        }
      }
      i.backup(1);
      if (i.consume(marker)) {
        size += marker.length();
        if (i.hasNext() && i.peek() != '\n') {
          i.backup(size);
          return false;
        }
        if (!consume) {
          i.backup(size);
        }
        return true;
      }
      i.backup(size);
      return false;
    }

    private Tokens readStrEv(MirahLexer l, Input i) {
      i.backup(1);
      if (i.consume('{')) {
        l.pushState(l.state.previous.lexer);
        return Tokens.tStrEvBegin;
      } else if (i.peek() == '@') {
        l.pushForOneToken(l.state.previous.lexer);
        return Tokens.tStrEvBegin;
      } else {
        return Tokens.tUNKNOWN;
      }
    }
  }

  private static class StandardLexer implements Lexer {
    @Override
    public Tokens lex(MirahLexer l, Input i) {
      Tokens type = processFirstChar(l, i);
      type = checkKeyword(type, i);
      return readRestOfToken(type, l, i);
    }

    @Override
    public Tokens skipWhitespace(MirahLexer l, Input i) {
      boolean found_whitespace = false;
      ws:
      for (int c = i.read(); c != EOF; c = i.read()) {
        switch(c) {
        case ' ': case '\t': case '\r': case '\f': case 11:
          found_whitespace = true;
          break;
        case '\\':
          if (i.consume('\n')) {
            l.noteNewline();
            found_whitespace = true;
            break;
          }
          break ws;
        case '#':
          if (found_whitespace) {
            break ws;
          }
          i.consumeLine();
          return Tokens.tComment;
        case '/':
          if (i.consume('*')) {
            return readBlockComment(l, i);
          }
          break ws;
        default:
          break ws;
        }
      }
      i.backup(1);
      if (found_whitespace) {
        return Tokens.tWhitespace;
      }
      return null;
    }

    private Tokens readBlockComment(MirahLexer l, Input i) {
      boolean javadoc = i.peek() == '*';
      for (int c = i.read(); c != EOF; c = i.read()) {
        switch(c) {
        case '\n':
          l.noteNewline();
          break;
        case '*':
          if (i.consume('/')) {
            return javadoc ? Tokens.tJavaDoc : Tokens.tComment;
          }
          break;
        case '/':
          if (i.consume('*')) {
            readBlockComment(l, i);
          }
          break;
       }
      }
      return l.unterminatedComment();
    }

    private Tokens processFirstChar(MirahLexer l, Input i) {
      Tokens type = null;
      int c0 = i.read();
      switch (c0) {
      case -1:
        if (l.state.hereDocs.isEmpty()) {
          type = Tokens.tEOF;
        } else {
          type = Tokens.tHereDocBegin;
        }
        break;
      case '$':
        type = Tokens.tDollar;
        break;
      case '@':
        if (i.consume("@`")) {
          type = Tokens.tClassVarBacktick;
        } else if (i.consume('@') && i.hasNext()) {
          type = Tokens.tClassVar;
        } else if (i.consume('`')) {
          type = Tokens.tInstVarBacktick;
        } else if (i.hasNext()) {
          type = Tokens.tInstVar;
        }
        break;
      case '_':
        if (i.consume("_ENCODING__")) {
          type = Tokens.t__ENCODING__;
        } else if (i.consume("_FILE__")) {
          type = Tokens.t__FILE__;
        } else if (i.consume("_LINE__")) {
          type = Tokens.t__LINE__;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'B':
        if (i.consume("EGIN")) {
          type = Tokens.tBEGIN;
        } else {
          type = Tokens.tCONSTANT;
        }
        break;
      case 'E':
        if (i.consume("ND")) {
          type = Tokens.tEND;
        } else {
          type = Tokens.tCONSTANT;
        }
        break;
      case 'a':
        if (i.consume("lias")) {
          type = Tokens.tAlias;
        } else if (i.consume("nd")) {
          type = Tokens.tAnd;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'b':
        if (i.consume("egin")) {
          type = Tokens.tBegin;
        } else if (i.consume("reak")) {
          type = Tokens.tBreak;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'c':
        if (i.consume("ase")) {
          type = Tokens.tCase;
        } else if (i.consume("lass")) {
          type = Tokens.tClass;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'd':
        if (i.consume("efined")) {
          type = Tokens.tDefined;
        } else if (i.consume("efmacro")) {
          type = Tokens.tDefmacro;
        } else if (i.consume("ef")) {
          type = Tokens.tDef;
        } else if (i.consume("o")) {
          type = Tokens.tDo;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'e':
        if (i.consume("lse")) {
          type = Tokens.tElse;
        } else if (i.consume("lsif")) {
          type = Tokens.tElsif;
        } else if (i.consume("nd")) {
          type = Tokens.tEnd;
        } else if (i.consume("nsure")) {
          type = Tokens.tEnsure;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'f':
        if (i.consume("alse")) {
          type = Tokens.tFalse;
        } else if (i.consume("or")) {
          type = Tokens.tFor;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'i':
        if (i.consume("f")) {
          type = Tokens.tIf;
        } else if (i.consume("mplements")) {
          type = Tokens.tImplements;
        } else if (i.consume("mport")) {
          type = Tokens.tImport;
        } else if (i.consume("nterface")) {
          type = Tokens.tInterface;
        } else if (i.consume("n")) {
          type = Tokens.tIn;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'm':
        if (i.consume("acro")) {
          type = Tokens.tMacro;
        } else if (i.consume("odule")) {
          type = Tokens.tModule;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'n':
        if (i.consume("ext")) {
          type = Tokens.tNext;
        } else if (i.consume("il")) {
          type = Tokens.tNil;
        } else if (i.consume("ot")) {
          type = Tokens.tNot;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'o':
        if (i.consume("r")) {
          type = Tokens.tOr;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'p':
        if (i.consume("ackage")) {
          type = Tokens.tPackage;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'r':
        if (i.consume("aise")) {
          type = Tokens.tRaise;
        } else if (i.consume("edo")) {
          type = Tokens.tRedo;
        } else if (i.consume("escue")) {
          type = Tokens.tRescue;
        } else if (i.consume("etry")) {
          type = Tokens.tRetry;
        } else if (i.consume("eturn")) {
          type = Tokens.tReturn;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 's':
        if (i.consume("elf")) {
          type = Tokens.tSelf;
        } else if (i.consume("uper")) {
          type = Tokens.tSuper;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 't':
        if (i.consume("hen")) {
          type = Tokens.tThen;
        } else if (i.consume("rue")) {
          type = Tokens.tTrue;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'u':
        if (i.consume("ndef")) {
          type = Tokens.tUndef;
        } else if (i.consume("nless")) {
          type = Tokens.tUnless;
        } else if (i.consume("ntil")) {
          type = Tokens.tUntil;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'w':
        if (i.consume("hen")) {
          type = Tokens.tWhen;
        } else if (i.consume("hile")) {
          type = Tokens.tWhile;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'y':
        if (i.consume("ield")) {
          type = Tokens.tYield;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case '\n':
        l.noteNewline();
        if (l.state.hereDocs.isEmpty()) {
          type = Tokens.tNL;
        } else {
          type = Tokens.tHereDocBegin;
          l.pushState(l.state.hereDocs.removeFirst());
        }
        break;
      case '/':
        if (l.isBEG()) {
          l.pushState(new RegexLexer());
          type = Tokens.tRegexBegin;
        } else if (!i.hasNext()) {
          type = Tokens.tSlash;
        } else if (i.consume('=')) {
            type = Tokens.tOpAssign;
        } else if (l.isARG() && l.spaceSeen && !Character.isWhitespace(i.peek())) {
          // warn("Ambiguous first argument; make sure.")
          type = Tokens.tRegexBegin;
        } else {
          type = Tokens.tSlash;
        }
        break;
      case '\'':
        l.pushState(new SStringLexer());
        type = Tokens.tSQuote;
        break;
      case '"':
        l.pushState(new DStringLexer());
        type = Tokens.tDQuote;
        break;
      case ':':
        if (i.consume(':')) {
          type = Tokens.tColons;
        } else {
          type = Tokens.tColon;
        }
        break;
      case '.':
        if (i.consume('.')) {
          type = Tokens.tDots;
        } else {
          type = Tokens.tDot;
        }
        break;
      case '(':
        type = Tokens.tLParen;
        break;
      case ')':
        type = Tokens.tRParen;
        break;
      case '[':
        type = Tokens.tLBrack;
        break;
      case ']':
        type = Tokens.tRBrack;
        break;
      case '{':
        l.state.lbrace();
        type = Tokens.tLBrace;
        break;
      case '}':
        l.state.rbrace(l);
        type = Tokens.tRBrace;
        break;
      case ';':
        type = Tokens.tSemi;
        break;
      case '!':
        if (i.consume('=')) {
          if (i.consume('=')) {
            type = Tokens.tNEE;
          } else {
            type = Tokens.tNE;
          }
        } else if (i.consume('~')) {
          type = Tokens.tNMatch;
        } else {
          type = Tokens.tBang;
        }
        break;
      case '<':
        if (i.consume('=')) {
          if (i.consume('>')) {
            type = Tokens.tLEG;
          } else {
            type = Tokens.tLE;
          }
        } else if (i.consume('<')) {
          if (i.consume('<')) {
            if (i.consume('=')) {
              type = Tokens.tOpAssign;
            }
          } else if (i.consume('=')) {
            type = Tokens.tOpAssign;
          } else {
            type = Tokens.tLShift;
          }
        } else {
          type = Tokens.tLT;
        }
        break;
      case '>':
        if (i.consume('=')) {
          type = Tokens.tGE;
        } else if (i.consume('>')) {
          if (i.consume('=')) {
            type = Tokens.tOpAssign;
          } else {
              if(i.consume('>')) {
                  type = Tokens.tRRShift;
              }else {
                  type = Tokens.tRShift;
              }
          }
        } else {
          type = Tokens.tGT;
        }
        break;
      case '?':
        type = Tokens.tQuestion;
        break;
      case '=':
        if (i.consume('>')) {
          type = Tokens.tRocket;
        } else if (i.consume('~')) {
          type = Tokens.tMatch;
        } else if (i.consume('=')) {
          if (i.consume('=')) {
            type = Tokens.tEEEQ;
          } else {
            type = Tokens.tEEQ;
          }
        } else {
          type = Tokens.tEQ;
        }
        break;
      case '&':
        if (i.consume('&')) {
          if (i.consume('=')) {
            type = Tokens.tAndEq;
          } else {
            type = Tokens.tAmpers;
          }
        } else if (i.consume('=')) {
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tAmper;
        }
        break;
      case '|':
        if (i.consume('|')) {
          if (i.consume('=')) {
            type = Tokens.tOrEq;
          } else {
            type = Tokens.tPipes;
          }
        } else if (i.consume('=')) {
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tPipe;
        }
        break;
      case '*':
        if (i.consume('*')) {
          if (i.consume('=')) {
            type = Tokens.tOpAssign;
          } else {
            type = Tokens.tStars;
          }
        } else if (i.consume('=')) {
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tStar;
        }
        break;
      case '+':
        if (i.consume('=')) {
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tPlus;
        }
        break;
      case '-':
        if (i.consume('=')) {
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tMinus;
        }
        break;
      case '%':
        if (i.consume('=')) {
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tPercent;
        }
        break;
      case '^':
        if (i.consume('=')) {
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tCaret;
        }
        break;
      case '~':
        type = Tokens.tTilde;
        break;
      case '`':
        type = Tokens.tBacktick;
        break;
      case ',':
        type = Tokens.tComma;
        break;
      case '0': case '1': case '2': case '3': case '4':
      case '5': case '6': case '7': case '8': case '9':
        type = Tokens.tDigit;
        break;
      default:
        // Note, I'm treating all surrogate pairs as identifier chars.
        // We can fix that if it's ever a problem.
        if ((c0 >= 'A' && c0 <= 'Z') ||
            Character.isUpperCase(c0)) {
          type = Tokens.tCONSTANT;
        } else if (c0 >= 0xD800 && c0 <= 0xDBFF) {
          if (Character.isUpperCase(i.finishCodepoint())) {
            type = Tokens.tCONSTANT;
          } else {
            type = Tokens.tIDENTIFIER;
          }
        } else if ((c0 >= 'a' && c0 <= 'z') ||
                   (c0 > 0x7f && Character.isLetter(c0))) {
          type = Tokens.tIDENTIFIER;
        } else {
          type = Tokens.tUNKNOWN;
        }
      }
      return type;
    }

    private Tokens checkKeyword(Tokens type, Input i) {
      // If we found a keyword, see if it's just the beginning of another name
      if (Tokens.tClassVar.compareTo(type) > 0) {
        int c1 = i.peek();
        if ((c1 >= 0xD800 && c1 <= 0xDFFF) ||
            Character.isLetterOrDigit(c1) ||
            c1 == '_') {
          if (type == Tokens.tBEGIN || type == Tokens.tEND) {
            type = Tokens.tCONSTANT;
          } else {
            type = Tokens.tIDENTIFIER;
          }
        }
      }
      return type;
    }

    private Tokens readRestOfToken(Tokens type, MirahLexer l, Input i) {
      switch (type) {
        case tDigit:
          return readNumber(i);
        case tQuestion:
          return readCharacter(i);
        case tLShift:
          return readHereDocIdentifier(l, i);
      }
      if (Tokens.tFID.compareTo(type) >= 0) {
        return readName(i, type);
      }
      return type;
    }

    private Tokens readName(Input i, Tokens type) {
      int start = i.pos();
      for (int c = i.read(); c != EOF; c = i.read()) {
        if (c <= 0x7F) {
          if (c == '_' ||
              (c >= '0' && c <= '9') ||
              (c >= 'A' && c <= 'Z') ||
              (c >= 'a' && c <= 'z')) {
            continue;
          } else if (c == '?' || c == '!') {
            if (i.consume('=')) {
              i.backup(1);
              break;
            } else {
              return Tokens.tFID;
            }
          }
          break;
        } else if (c >= 0xD800 && c <= 0xDFFF) {
          continue;
        } else {
          if (!Character.isLetterOrDigit(c)) {
            break;
          }
        }
      }
      i.backup(1);
      if (type == Tokens.tInstVar && i.pos() == start) {
        type = Tokens.tAt;
      }
      return type;
    }

    private void readDigits(Input i, boolean oct, boolean dec, boolean hex) {
      loop:
      for (int c = i.read(); c != EOF; c = i.read()) {
        switch (c) {
          case '0': case '1': case '_':
            break;
          case '2': case '3': case '4': case '5': case '6': case '7':
            if (oct) {
              break;
            } else {
              i.backup(1);
              return;
            }
          case '8': case '9':
            if (dec) {
              break;
            } else {
              i.backup(1);
              return;
            }
          case 'a': case 'A': case 'b': case 'B': case 'c': case 'C':
          case 'd': case 'D': case 'e': case 'E': case 'f': case 'F':
            if (hex) {
              break;
            } else {
              i.backup(1);
              return;
            }
          default:
            i.backup(1);
            return;
        }
      }
      i.backup(1);
    }

    private Tokens readNumber(Input i) {
      if (!i.hasNext()) {
        return Tokens.tInteger;
      }
      boolean oct = true;
      boolean dec = true;
      boolean hex = false;
      boolean maybeFloat = true;
      i.backup(1);
      if (i.consume('0')) {
        switch (i.read()) {
          case 'd': case 'D':
            maybeFloat = false;
            break;
          case 'b': case 'B':
            oct = dec = maybeFloat = false;
            break;
          case 'x': case 'X':
            hex = true;
            maybeFloat = false;
            break;
          case '.': case 'e': case 'E':
            i.backup(1);
            break;
          case 'o': case 'O':
            dec = false;
            break;
          default:
            i.backup(1);
            maybeFloat = false;
            dec = false;
        }
      }
      readDigits(i, oct, dec, hex);
      if (maybeFloat && i.hasNext()) {
        if (i.consume('.')) {
          if (readFraction(i)) {
            return Tokens.tFloat;
          } else {
            i.backup(1);
          }
        } else if (i.consume('e') || i.consume('E')) {
          readExponent(i);
          return Tokens.tFloat;
        }
      }
      return Tokens.tInteger;
    }

    private boolean readFraction(Input i) {
      int start = i.pos();
      readDigits(i, true, true, false);
      if (start == i.pos()) {
        return false;
      }
      if (i.hasNext()) {
        if (i.consume('e') || i.consume('E')) {
          readExponent(i);
          return true;
        }
      }
      return true;
    }

    private void readExponent(Input i) {
      i.consume('-');
      readDigits(i, true, true, false);
    }

    private boolean isIdentifierChar(int c) {
      if (c == EOF) {
        return false;
      }
      return Character.isLetterOrDigit(c) || c == '_' || (c >= 0xD800 && c <= 0xDBFF);
    }

    private Tokens readCharacter(Input i) {
      if (!i.hasNext()) {
        return Tokens.tQuestion;
      }
      int c = i.read();
      if (c == EOF || Character.isWhitespace(c)) {
        i.backup(1);
        return Tokens.tQuestion;
      }
      if ((c == '_' || Character.isLetterOrDigit(c)) &&
          isIdentifierChar(i.peek())) {
        i.backup(1);
        return Tokens.tQuestion;
      }
      if (c >= 0xD800 && c <= 0xDBFF) {
        i.skip(1);
        if (isIdentifierChar(i.peek())) {
          i.backup(2);
          return Tokens.tQuestion;
        }
        return Tokens.tCharacter;
      }
      if (c != '\\') {
        return Tokens.tCharacter;
      }
//      if (i.consume('\\')) {
//        return Tokens.tCharacter;
//      }
      // Just gobble up any digits. Let the parser worry about whether it's a
      // valid escape.
      while (EOF != (c = i.read())) {
        switch (c) {
          case '0': case '1': case '2': case '3': case '4': case '5': case '6':
          case '7': case '8': case '9': case 'a': case 'A': case 'b': case 'B':
          case 'c': case 'C': case 'd': case 'D': case 'e': case 'E': case 'f':
          case 'F': case 'x': case 'u': case 'U':
            continue;
        }
        break;
      }
      if (c == EOF || Character.isWhitespace(c)) {
        i.backup(1);
      }
      return Tokens.tCharacter;
    }

    private Tokens readHereDocIdentifier(MirahLexer l, Input i) {
      int start = i.pos();
      boolean allowIndented = false;
      if (!i.hasNext() || l.isEND() || (l.isARG() && !l.spaceSeen)) {
        return Tokens.tLShift;
      }
      if (i.consume('-')) {
        allowIndented = true;
      }
      char quote = 0;
      if (i.consume('"')) {
        quote = '"';
      } else if (i.consume('\'')) {
        quote = '\'';
      }
      int id_start = i.pos();
      for (int c = i.read(); c != EOF; c = i.read()) {
        if (!isIdentifierChar(c)) {
          break;
        }
      }
      i.backup(1);
      if (i.pos() == id_start) {
        return Tokens.tLShift;
      }
      CharSequence id = i.readBack(i.pos() - id_start);
      if (quote != 0) {
        if (!i.consume(quote)) {
          i.backup(i.pos() - start);
          return Tokens.tLShift;
        }
      }
      l.state.hereDocs.add(new HereDocLexer(id.toString(), allowIndented, quote != '\''));
      return Tokens.tHereDocId;
    }
  }

  public MirahLexer(String string, char[] chars, BaseParser parser) {
    this(new StringInput(string, chars));
    this.parser = parser;
  }
  
  public MirahLexer(Input input) {
    this.input = input;
    pushState(new StandardLexer());
    argTokens = EnumSet.of(Tokens.tSuper, Tokens.tYield, Tokens.tIDENTIFIER,
                           Tokens.tCONSTANT, Tokens.tFID);
    beginTokens = EnumSet.range(Tokens.tBang, Tokens.tOpAssign);
    beginTokens.addAll(EnumSet.of(
        Tokens.tElse, Tokens.tCase, Tokens.tEnsure, /*Tokens.tModule,*/
        Tokens.tElsif, Tokens.tNot, Tokens.tThen, Tokens.tFor, Tokens.tReturn,
        Tokens.tIf, Tokens.tIn, Tokens.tDo, Tokens.tUntil, Tokens.tUnless,
        Tokens.tOr, Tokens.tWhen, Tokens.tAnd, Tokens.tBegin, Tokens.tWhile,
        Tokens.tNL, Tokens.tSemi, Tokens.tColon, Tokens.tSlash, Tokens.tLBrace,
        Tokens.tLBrack, Tokens.tLParen, Tokens.tDots));
    beginTokens.addAll(EnumSet.range(Tokens.tComma, Tokens.tRocket));
    // Comment?
    endTokens = EnumSet.of(
        Tokens.tDot, Tokens.tCharacter, Tokens.tSQuote, Tokens.tDQuote,
        Tokens.tRParen, Tokens.tRBrace, Tokens.tRBrack, Tokens.tRegexEnd,
        Tokens.tInteger, Tokens.tFloat, Tokens.tInstVar, Tokens.tClassVar,
        Tokens.tEnd, Tokens.tSelf, Tokens.tFalse, Tokens.tTrue, Tokens.tRetry,
        Tokens.tBreak, Tokens.tNil, Tokens.tNext, Tokens.tRedo, Tokens.tClass,
        Tokens.tDef);
  }

  private boolean isBEG() {
    return isBEG;
  }

  private boolean isARG() {
    return isARG;
  }

  private boolean isEND() {
    return isEND;
  }

  private void pushState(Lexer lexer) {
    this.state = new State(this.state, lexer);
  }

  private void pushForOneToken(Lexer lexer) {
    this.state = new State(this.state, lexer, true);
  }

  private void popState() {
    if (state.previous != null) {
      state = state.previous;
    }
  }

  public Tokens simpleLex() {
    boolean shouldPop = state.justOnce;
    Tokens type = state.lexer.skipWhitespace(this, input);
    if (type != null) {
      spaceSeen = true;
      return type;
    }
    type = state.lexer.lex(this, input);
    if (shouldPop) {
      popState();
    }
    spaceSeen = false;
    isBEG = beginTokens.contains(type);
    isARG = argTokens.contains(type);
    isEND = endTokens.contains(type);
    return type;
  }
  

  public Token<Tokens> lex(int pos) {
    return lex(pos, true);
  }

  public Token<Tokens> lex(int pos, boolean skipWhitespaceAndComments) {
    if (pos < input.pos()) {
      ListIterator<Token<Tokens>> it = tokens.listIterator(tokens.size());
      while (it.hasPrevious()) {
        Token<Tokens> savedToken = it.previous();
        if (pos >= savedToken.pos && pos <= savedToken.startpos) {
          logger.fine("Warning, uncached token " + savedToken.type + " at " + pos);
          parser._pos = savedToken.endpos;
          return savedToken;
        }
      }
      throw new IllegalArgumentException("" + pos + " < " + input.pos());
    } else if (!input.hasNext()) {
      return parser.build_token(state.hereDocs.isEmpty() ? Tokens.tEOF : Tokens.tHereDocBegin, pos, pos);
    }
    Tokens type = Tokens.tWhitespace;
    int start = input.pos();
    if (skipWhitespaceAndComments) {
        while (type.ordinal() > Tokens.tEOF.ordinal()) {
          start = input.pos();
          type = simpleLex();
        }
    } else {
        start = input.pos();
        type = simpleLex();
    }
    parser._pos = input.pos();
    Token<Tokens> token = parser.build_token(type, pos, start);
    tokens.add(token);
    return token;
  }
  
  void noteNewline() {
    if (parser != null) {
      parser.note_newline(input.pos());
    }
  }

  public Tokens unterminatedComment() {
    if (parser == null) {
      return Tokens.tPartialComment;
    } else {
      throw new SyntaxError("terminated comment", "*/", parser._pos, parser._string, parser._list);
    }
  }

  public Object getState() {
    if (state.previous == null && state.hereDocs.isEmpty() && state.braceDepth < 0x20) {
      int compressed = 0;
      if (isBEG) {
        compressed = 1;
      } else if (isEND) {
        compressed = 2;
      } else if (isARG) {
        if (spaceSeen) {
          compressed = 4;
        } else {
          compressed = 3;
        }
      }
      compressed |= (state.braceDepth << 3);
      return compressed;
    }
    return new CombinedState(this);
  }

  public void restore(Object state) {
    if (state instanceof CombinedState) {
      CombinedState cs = (CombinedState)state;
      this.state = cs.state;
      spaceSeen = cs.spaceSeen;
      isBEG = cs.isBEG;
      isARG = cs.isARG;
      isEND = cs.isEND;
    } else {
      int compressed = ((Integer)state).intValue();
      this.state = new State(null, new StandardLexer());
      this.state.braceDepth = (compressed >> 3) & 0x1f;
      isBEG = isARG = isEND = spaceSeen = false;
      switch (compressed & 0x7) {
        case 1:
          isBEG = true;
          break;
        case 2:
          isEND = true;
          break;
        case 4:
          spaceSeen = true;
          // fall through;
        case 3:
          isARG = true;
          break;
      }
    }
  }

  private Input input;
  private BaseParser parser;
  private State state;
  private ArrayList<Token<Tokens>> tokens = new ArrayList<Token<Tokens>>();
  private EnumSet<Tokens> beginTokens;
  private EnumSet<Tokens> argTokens;
  private EnumSet<Tokens> endTokens;
  private boolean spaceSeen = false;
  private boolean isBEG = true;
  private boolean isARG = false;
  private boolean isEND = false;
}
