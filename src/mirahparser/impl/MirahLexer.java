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

import mmeta.BaseParser;
import mmeta.BaseParser.Token;

public class MirahLexer {
  public MirahLexer(String string, char[] chars, BaseParser parser) {
    this.string = string;
    this.chars = chars;
    this.end = chars.length;
    this.parser = parser;
  }

  public Token<Tokens> lex(int pos) {
    int start = skipWhitespace(pos);
    Tokens type = processFirstChar(start);
    type = checkKeyword(type);
    type = readRestOfToken(type);
    return parser.build_token(type, pos, start);
  }

  private int skipWhitespace(int pos) {
    int i = pos;
    ws:
    while (i < end) {
      switch(chars[i]) {
      case ' ': case '\t': case '\r': case '\f': case 11:
        break;
      case '\\':
        if (i + 1 < end && chars[i + 1] == '\n') {
          parser.note_newline(i + 1);
          i += 1;
          break;
        }
        break ws;
      case '#':
        i = string.indexOf('\n', i + 1);
        if (i == -1) {
          i = end;
        }
        break ws;
      case '/':
        if (i + 1 < end && chars[i + 1] == '*') {
          i = skipBlockComment(i + 2);
          break;
        }
        break ws;
      default:
        break ws;
      }
      i += 1;
    }
    return i;
  }

  private int skipBlockComment(int start) {
    int i = start;
    while (i < end) {
      switch(chars[i]) {
      case '\n':
        parser.note_newline(i);
        break;
      case '*':
        if (i + 1 < end && chars[i + 1] == '/') {
          return i + 1;
        }
        break;
      case '/':
        if (i + 1 < end && chars[i + 1] == '*') {
          i = skipBlockComment(i + 2);
        }
        break;
     }
      i += 1;
    }
    throw new mmeta.SyntaxError("*/", "*/", end, string, null);
  }

  private Tokens processFirstChar(int i) {
    Tokens type = null;
    if (i == end) {
      type = Tokens.tEOF;
    } else {
      char c0 = chars[i];
      i += 1;
      switch (c0) {
      case '$':
        type = Tokens.tDollar;
        break;
      case '@':
        if (string.startsWith("@`", i)) {
          i += 2;
          type = Tokens.tClassVarBacktick;
        } else if (string.startsWith("@", i) && i + 1 < end) {
          i += 1;
          type = Tokens.tClassVar;
        } else if (string.startsWith("`", i)) {
          i += 1;
          type = Tokens.tInstVarBacktick;
        } else if (i < end) {
          type = Tokens.tInstVar;
        }
        break;
      case '_':
        if (string.startsWith("_ENCODING__", i)) {
          type = Tokens.t__ENCODING__;
          i += 11;
        } else if (string.startsWith("_FILE__", i)) {
          type = Tokens.t__FILE__;
          i += 7;
        } else if (string.startsWith("_LINE__", i)) {
          type = Tokens.t__LINE__;
          i += 7;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'B':
        if (string.startsWith("EGIN", i)) {
          type = Tokens.tBEGIN;
          i += 4;
        } else {
          type = Tokens.tCONSTANT;
        }
        break;
      case 'E':
        if (string.startsWith("ND", i)) {
          type = Tokens.tEND;
          i += 2;
        } else {
          type = Tokens.tCONSTANT;
        }
        break;
      case 'a':
        if (string.startsWith("lias", i)) {
          type = Tokens.tAlias;
          i += 4;
        } else if (string.startsWith("nd", i)) {
          type = Tokens.tAnd;
          i += 2;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'b':
        if (string.startsWith("egin", i)) {
          type = Tokens.tBegin;
          i += 4;
        } else if (string.startsWith("reak", i)) {
          type = Tokens.tBreak;
          i += 4;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'c':
        if (string.startsWith("ase", i)) {
          type = Tokens.tCase;
          i += 3;
        } else if (string.startsWith("lass", i)) {
          type = Tokens.tClass;
          i += 4;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'd':
        if (string.startsWith("efined", i)) {
          type = Tokens.tDefined;
          i += 6;
        } else if (string.startsWith("ef", i)) {
          type = Tokens.tDef;
          i += 2;
        } else if (string.startsWith("o", i)) {
          type = Tokens.tDo;
          i += 1;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'e':
        if (string.startsWith("lse", i)) {
          type = Tokens.tElse;
          i += 3;
        } else if (string.startsWith("lsif", i)) {
          type = Tokens.tElsif;
          i += 4;
        } else if (string.startsWith("nd", i)) {
          type = Tokens.tEnd;
          i += 2;
        } else if (string.startsWith("nsure", i)) {
          type = Tokens.tEnsure;
          i += 5;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'f':
        if (string.startsWith("alse", i)) {
          type = Tokens.tFalse;
          i += 4;
        } else if (string.startsWith("or", i)) {
          type = Tokens.tFor;
          i += 2;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;      
      case 'i':
        if (string.startsWith("f", i)) {
          type = Tokens.tIf;
          i += 1;
        } else if (string.startsWith("n", i)) {
          type = Tokens.tIn;
          i += 1;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'm':
        if (string.startsWith("odule", i)) {
          type = Tokens.tModule;
          i += 5;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'n':
        if (string.startsWith("ext", i)) {
          type = Tokens.tNext;
          i += 3;
        } else if (string.startsWith("il", i)) {
          type = Tokens.tNil;
          i += 2;
        } else if (string.startsWith("ot", i)) {
          type = Tokens.tNot;
          i += 2;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'o':
        if (string.startsWith("r", i)) {
          type = Tokens.tOr;
          i += 1;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'r':
        if (string.startsWith("edo", i)) {
          type = Tokens.tRedo;
          i += 3;
        } else if (string.startsWith("escue", i)) {
          type = Tokens.tRescue;
          i += 5;
        } else if (string.startsWith("etry", i)) {
          type = Tokens.tRetry;
          i += 4;
        } else if (string.startsWith("eturn", i)) {
          type = Tokens.tReturn;
          i += 5;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 's':
        if (string.startsWith("elf", i)) {
          type = Tokens.tSelf;
          i += 3;
        } else if (string.startsWith("uper", i)) {
          type = Tokens.tSuper;
          i += 4;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 't':
        if (string.startsWith("hen", i)) {
          type = Tokens.tThen;
          i += 3;
        } else if (string.startsWith("rue", i)) {
          type = Tokens.tTrue;
          i += 3;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'u':
        if (string.startsWith("ndef", i)) {
          type = Tokens.tUndef;
          i += 4;
        } else if (string.startsWith("nless", i)) {
          type = Tokens.tUnless;
          i += 5;
        } else if (string.startsWith("ntil", i)) {
          type = Tokens.tUntil;
          i += 4;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'w':
        if (string.startsWith("hen", i)) {
          type = Tokens.tWhen;
          i += 3;
        } else if (string.startsWith("hile", i)) {
          type = Tokens.tWhile;
          i += 4;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case 'y':
        if (string.startsWith("ield", i)) {
          type = Tokens.tYield;
          i += 4;
        } else {
          type = Tokens.tIDENTIFIER;
        }
        break;
      case '\n':
        parser.note_newline(i);
        type = Tokens.tNL;
        break;
      case '/':
        if (i < end && chars[i] == '=') {
          i += 1;
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tSlash;
        }
        break;
      case '\'':
      case '"':
        type = Tokens.tQuote;
        break;
      case ':':
        if (i < end && chars[i] == ':') {
          i += 1;
          type = Tokens.tColons;
        } else {
          type = Tokens.tColon;
        }
        break;
      case '.':
        if (i < end && chars[i] == '.') {
          i += 1;
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
        type = Tokens.tLBrace;
        break;
      case '}':
        type = Tokens.tRBrace;
        break;
      case ';':
        type = Tokens.tSemi;
        break;
      case '!':
        if (i < end) {
          switch (chars[i]) {
          case '=':
            i += 1;
            type = Tokens.tNE;
            break;
          case '~':
            i += 1;
            type = Tokens.tNMatch;
            break;
          default:
            type = Tokens.tBang;
          }
        } else {
          type = Tokens.tBang;
        }
        break;
      case '<':
        if (i < end) {
          switch (chars[i]) {
            case '=':
              if (i + 1 < end && chars[i + 1] == '>') {
                i += 2;
                type = Tokens.tLEG;
              } else {
                i += 1;
                type = Tokens.tLE;
              }
              break;
            case '<':
              if (i + 1 < end && chars[i + 1] == '<') {
                if (i + 2 < end && chars[i + 2] == '=') {
                  i += 3;
                  type = Tokens.tOpAssign;
                } else {
                  i += 2;
                  type = Tokens.tLLShift;
                }
              } else if (i + 1 < end && chars[i + 1] == '=') {
                i += 2;
                type = Tokens.tOpAssign;
              } else {
                i += 1;
                type = Tokens.tLShift;
              }
              break;
            default:
              type = Tokens.tLT;
          }
        } else {
          type = Tokens.tLT;
        }
        break;
      case '>':
        if (i < end) {
          char c = chars[i];
          if (c == '=') {
            i += 1;
            type = Tokens.tGE;
          } else if (c == '>') {
            if (i + 1 < end && chars[i + 1] == '=') {
              i += 2;
              type = Tokens.tOpAssign;
            } else {
              i += 1;
              type = Tokens.tRShift;
            }
          } else {
            type = Tokens.tGT;
          }
        } else {
          type = Tokens.tGT;
        }
        break;
      case '?':
        type = Tokens.tQuestion;
        break;
      case '=':
        if (i == end) {
          type = Tokens.tEQ;
        } if (chars[i] == '>') {
          i += 1;
          type = Tokens.tRocket;
        } else if (chars[i] == '~') {
          i += 1;
          type = Tokens.tMatch;
        } else if (chars[i] == '=') {
          if (i + 1 < end && chars[i + 1] == '=') {
            i += 2;
            type = Tokens.tEEEQ;
          } else {
            i += 1;
            type = Tokens.tEEQ;
          }
        } else {
          type = Tokens.tEQ;
        }
        break;
      case '&':
        if (i < end && chars[i] == '&') {
          if (i + 1 < end && chars[i + 1] == '=') {
            i += 2;
            type = Tokens.tAndEq;
          } else {
            i += 1;
            type = Tokens.tAmpers;
          }
        } else if (i < end && chars[i] == '=') {
          i += 1;
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tAmper;
        }
        break;
      case '|':
        if (i < end && chars[i] == '|') {
          if (i + 1 < end && chars[i + 1] == '=') {
            i += 2;
            type = Tokens.tOrEq;
          } else {
            i += 1;
            type = Tokens.tPipes;
          }
        } else if (i < end && chars[i] == '=') {
          i += 1;
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tPipe;
        }
        break;
      case '*':
        if (i < end && chars[i] == '*') {
          if (i + 1 < end && chars[i + 1] == '=') {
            i += 2;
            type = Tokens.tOpAssign;
          } else {
            i += 1;
            type = Tokens.tStars;
          }
        } else if (i < end && chars[i] == '=') {
          i += 1;
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tStar;
        }
        break;
      case '+':
        if (i < end && chars[i] == '=') {
          i += 1;
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tPlus;
        }
        break;
      case '-':
        if (i < end && chars[i] == '=') {
          i += 1;
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tMinus;
        }
        break;
      case '%':
        if (i < end && chars[i] == '=') {
          i += 1;
          type = Tokens.tOpAssign;
        } else {
          type = Tokens.tPercent;
        }
        break;
      case '^':
        if (i < end && chars[i] == '=') {
          i += 1;
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
          if (Character.isUpperCase(string.codePointAt(i - 1))) {
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
    }
    parser._pos = i;
    return type;
  }

  private Tokens checkKeyword(Tokens type) {
    // If we found a keyword, see if it's just the beginning of another name
    int i = parser._pos;
    if (Tokens.tClassVar.compareTo(type) > 0 && i < end) {
      char c1 = chars[i];
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

  private Tokens readRestOfToken(Tokens type) {
    int i = parser._pos;
    switch (type) {
      case tDigit:
        return readNumber(i);
      case tQuestion:
        return readCharacter(i);
    }
    if (Tokens.tFID.compareTo(type) >= 0) {
      return readName(i, type);
    }
    return type;
  }
  
  private Tokens readName(int pos, Tokens type) {
    int i = pos;
    while (i < end) {
      char c = chars[i];
      i += 1;
      if (c <= 0x7F) {
        if (c == '_' ||
            (c >= '0' && c <= '9') ||
            (c >= 'A' && c <= 'Z') ||
            (c >= 'a' && c <= 'z')) {
          continue;
        } else if (c == '?' || c == '!') {
          if (i < end && chars[i] == '=') {
            i -= 1;
          } else {
            type = Tokens.tFID;
          }
          break;
        }
        i -= 1;
        break;
      } else if (c >= 0xD800 && c <= 0xDFFF) {
        continue;
      } else {
        if (!Character.isLetterOrDigit(c)) {
          i -= 1;
          break;
        }
      }
    }
    if (i == parser._pos && type == Tokens.tInstVar) {
      type = Tokens.tAt;
    }
    parser._pos = i;
    return type;
  }

  private int readDigits(int pos, boolean oct, boolean dec, boolean hex) {
    loop:
    for (int i = pos; i < end; ++i) {
      switch (chars[i]) {
        case '0': case '1': case '_':
          break;
        case '2': case '3': case '4': case '5': case '6': case '7':
          if (oct) {
            break;
          } else {
            return i;
          }
        case '8': case '9':
          if (dec) {
            break;
          } else {
            return i;
          }
        case 'a': case 'A': case 'b': case 'B': case 'c': case 'C':
        case 'd': case 'D': case 'e': case 'E': case 'f': case 'F':
          if (hex) {
            break;
          } else {
            return i;
          }
        default:
          return i;
      }
    }
    return end;
  }

  private Tokens readNumber(int pos) {
    if (pos == end) {
      parser._pos = pos;
      return Tokens.tInteger;
    }
    boolean oct = true;
    boolean dec = true;
    boolean hex = false;
    boolean maybeFloat = true;
    if (chars[pos - 1] == '0') {
      switch (chars[pos]) {
        case 'd': case 'D':
          pos += 1;
          maybeFloat = false;
          break;
        case 'b': case 'B':
          oct = dec = maybeFloat = false;
          pos += 1;
          break;
        case 'x': case 'X':
          hex = true;
          maybeFloat = false;
          pos += 1;
        case '.': case 'e': case 'E':
          break;
        case 'o': case 'O':
          pos += 1;
        default:
          maybeFloat = false;
          dec = false;
      }
    }
    int i = readDigits(pos, oct, dec, hex);
    parser._pos = i;
    if (i == end || !maybeFloat) {
      return Tokens.tInteger;
    }
    switch (chars[i]) {
      case '.':
        if (readFraction(i + 1)) {
          return Tokens.tFloat;
        }
        break;
      case 'e': case 'E':
        readExponent(i + 1);
        return Tokens.tFloat;
    }
    return Tokens.tInteger;
  }

  private boolean readFraction(int pos) {
    int i = readDigits(pos, true, true, false);
    if (i == pos) {
      return false;
    }
    if (i < end) {
      if (chars[i] == 'e' || chars[i] == 'E') {
        readExponent(i + 1);
        return true;
      }
    }
    parser._pos = i;
    return true;
  }

  private void readExponent(int pos) {
    if (pos < end && chars[pos] == '-') {
      pos += 1;
    }
    parser._pos = readDigits(pos, true, true, false);
  }

  private boolean isIdentifierChar(char c) {
    return Character.isLetterOrDigit(c) || c == '_' || (c >= 0xD800 && c <= 0xDBFF);
  }

  private Tokens readCharacter(int pos) {
    if (pos == end) {
      return Tokens.tQuestion;
    }
    char c = chars[pos];
    if (Character.isWhitespace(c)) {
      return Tokens.tQuestion;
    }
    if (pos + 1 == end) {
      parser._pos = end;
      return Tokens.tCharacter;
    }
    char c1 = chars[pos + 1];
    if ((c == '_' || Character.isLetterOrDigit(c)) && isIdentifierChar(c1) ) {
      return Tokens.tQuestion;
    }
    if (c >= 0xD800 && c <= 0xDBFF) {
      if (pos + 2 < end && isIdentifierChar(chars[pos + 2])) {
        return Tokens.tQuestion;
      }
      parser._pos = pos + 2;
      return Tokens.tCharacter;
    }
    if (c != '\\') {
      parser._pos += 1;
      return Tokens.tCharacter;
    }
    // Just gobble up any digits. Let the parser worry about whether it's a
    // valid escape.
    int i;
    for (i = pos + 2; i < end; ++i) {
      c = chars[i];
      switch (chars[i]) {
        case '0': case '1': case '2': case '3': case '4': case '5': case '6':
        case '7': case '8': case '9': case 'a': case 'A': case 'b': case 'B':
        case 'c': case 'C': case 'd': case 'D': case 'e': case 'E': case 'f':
        case 'F':
          continue;
      }
      break;
    }
    parser._pos = i;
    return Tokens.tCharacter;
  }

  private String string;
  private char[] chars;
  private int end;
  private BaseParser parser;
}
