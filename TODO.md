- missing import should always show up in the summary of errors. eg

ERROR import X
ERROR fn X(1) doesn't exist

ERROR can't find type for import X



-- if a macro has a bug, the stacktrace is ugly



The TODO list of DOOM
=======================
100 char or less per feature, points included
syntax

    - (points) description

points logrithmicy difficulty 0-3
- 0 know what to do, how to do it, and it's trivial < 15 min
- 1 know what to do, how to do it, but not trivial < 1/2 day, > 1 hour
- 2 know what to do, but not how to do it, < 1 day, > 1/2 day
- 3 don't know exactly what to do, or how to do it, est is undefined


Dist
===========
- mirah-parser maven artifact https://github.com/mirah/mirah-parser/issues/16
- Java 8 ...
- look at java 9 features we could use
- update mvn compiler plugin
- add regression test for ant task example!
- rm implicit ant dependency... break out ant support as separate maven artifact
- mvn artifacts:
-- mirah-core
-- mirah-parser
-- mirah-ant
-- mirah


Compiler Internals Improvements
======================
- add generic warnings / error message facility
-- right now we've got errors and they're ok. but it'd be better if we had something better.
- make Mirror type systems addDefaultImports more obvious
- faster mirah compiler build: src => class is tricky, I could make src => jar, jar => jar tho
- switch to minitest
- tests for imports at different scopes
- shade asm lib for dev happiness
- keep version in fewer places whew. Current is
   version.rb
   various pom.xmls
   some random mirah file in src
- automated tests for distribution artifacts
  - verify bytecode version of compiler
    should have dist jar check that does this as part of acceptance suite

- silence logging from JRuby interfaces, unless overridden.

- get rid of all outputs that escape from tests
- move build artifacts to javalib for gem so that we don't depend on dist directory
- clean up javalib dir
- don't use 1.5 as java compile target
- make it obvious when ASTs have been dropped during macro expansion
- add timing to phases

- break compiler into phases
---------------
# parse
# typer prep

- sort files by import graph (could cache this)
- load macros
- load type systems
- load types for System, & predefs maybe?
- load scoped macros / extensions

# typer
- visit script body / class bodies, skipping method bodies
- compile macros
- visit method bodies

# finishs resolving typer wip
- resolve proxies
- change captured locals into binding fields

# clean up / compiler prep
- clean ast up

# compile

- maybe after parse, check built files to see if they need to be rebuilt, and ignore them otherwise
- investigate using Java 8 Lambda impl hooks for closures.

Warnings / Logging
============
- fix import not found so that it says can't find com.blah for import com.blah, or at least both package scoped & absolute packages. mirah#267
- warn about unused imports mirah#268
- initial not found should not be error in fine logging mirah#269
- log bindings as they are created 
- don't warn on self.initialize mirah#270
- can't find method error could list nearly matching methods mirah#271
- error on not all methods implemented for interfaces mirah#272

- improve duplicate name/sig error when multiple method defs w/ same sig mirah#273
- code sources from macro expansion should know both the macro location and the invoke location and report both on errors so that users know where to look to debug
- -v should only show the version, it currently says no main method too. :/
- add -Werror where warnings become errors
-   make block mirror type string a little nicer somehow 
eg Can't find method java.util.concurrent.locks.ReentrantLock.synchronize(org.mirah.jvm.mirrors.BlockType)

Parser
======
- variables w/ name package are not allowed :/ mirah-parser#18
- case expressions mirah-parser#17
- lambda literals mirah-parser#19

Features
==========
- each macro for Maps
- Reflection Macros
- AST formatter that converts back to something the parser can parse
- default toString?
- default hashCode / equals
- default val/no type that defers to indy
    eg
      def foo(x: int, y=1)
      end
    should work
- allow defining equals using def ==(other)
- attr_reader/et al as varargs instead of just Hash. It would mean that the type info would have to come from somewhere else
- goto: headius wants it
- synchronize intrinsic ala java's
- file scoped macros / extensions
- extension syntax
- public / private / protected / package scope helpers


  # test cases
  #  - method w/ no modifier, modifier statement, method
  #  - modifier statement, method
  #  - modifier statement, method, same modifier statement, method
  #  - modifier statement, method, different modifier statement, method
  #  - modifier statement, method containing closure w/ mdefs
  #  - modifier fn w/ undefined method
  #  - mdef, modifier fn mname
  #  - modifier statement, modifiered method
  #  - modifier statement, differently modifiered method
  #  - modifier statement, modifiered method, unmodifiered method
  #  - modifier statement, differently modifiered method, unmodifiered method

  #  pub
  #  def a
  # macro def self.public(mdef: MethodDefinition)
  # set annotation on it directly

  # macro def self.public(method_names: NodeList<Symbol> or something)
  #   find methods w/ those names, set anno on them directly
  #   if they don't exist, blow up
  #macro def self.public()
    # options
    # 1) grab typer & set current scope's default access *** best most likely
    # 2) don't expand here, instead throw into a queue, expand all at end
    # 3) try to infer defs needed to do it
  #end

- subclass access to super protected fields w/ @syntax
- (0) add a gets function like Ruby
- (2) a more "batteries included" set of imports
- (3) generics generics generics
- (???) ARGV
- (???) field access from closures, synthesize synthetic accessors
- (???) self in closures should be lexical self
- covariant interface impl overrides
- macro helpers for inserting things into initializers
- macro helpers for add method if not already there
- reverse macro on collections
- inner classes don't get nested names
    class A
      class B
      end
    end
    # => pkg.A, pkg.B
- understand Java 8 default methods
- default args on non-last position params. eg when a method takes a block(read: functional interface), it should be allowed to have default args before the block arg.
- do jruby style method lookup
- add env var hash constant ala Ruby's ENV.
- Thread extensions:
  Thread.start {}, which does t=Thread.new{};t.start;t
- macro for typecheck & cast. replace the x.kind_of? Y; Y(Object(x))

Bugs
==========
- a[-1] should work
- array ext size
- make sure that macro lookup looks at super classes
- "foo: #{x || y} acts weird", my guess is that interpolation doesn't generate the right code sometimes
- lambda's can't exist in methods! !! by which I mean that they can't close over things in methods. You can have them there, they just don't close. >:[]
- parser can't deal w/ unquotes in hash literals when key is unquote
  quote { puts `key`: 1 }
- implicit void methods w/ explicit return generate incorrect bytecode. Let's see if that's true of explicit. nope.
- import * doesn't always work correctly
- Inner class issues. Two inner classes w/ the same name will confuse the type system
  class A
    class B
      def b
        @b = 1
      end
    end
  end
class C
    class B
      def b
        @b = 1
      end
    end
  end

- if with no else has type of the bool expression not type of the body. It should return nil w/ the body type, or just be an error
  This might be just a error reporting issue
    ERROR: Invalid return type org.mirah.typer.Scope, expected org.mirah.typer.ResolvedType
            if parent
            ^^^^^^^^^


- constants are not referrable outside the defining scope :/ because they are private
- referring to classes as constants causes crashes
  java -jar dist/mirahc.jar -cp test/fixtures/ -e 'puts org::foo::A' blows up w/ a asm error
  java -jar dist/mirahc.jar -cp test/fixtures/ -e 'puts org::foo::A.class' doesn't

Libraries
===============
- delegation macro library
- (???) testing framework
- (???) fix up shatner
- (???) fix dubious


Compiled Code Usability
=======================
- name extension / macro classes after method name
- break annotations / macro build path to make javac happier
  currently macros are compiled to same tree as runtime code. We should make it so you can compile them to a different dir. Additionally, the annotations used for macros are unfriendly to javac, so we should put them in the macro dir

etc
=========

- overriding interface req type atm :( apparently. -- nope wrong method name
  interface Bar
    def bar(i: int):void;end
  end
  class Foo; implements Bar
    def bar(i) puts i; end
  end

- ArrayList.new(list) should do generic inference, perhaps, so T of list -> T of the resulting object

- when dealing in generics, error messages should highlight generic types somehow


blocks don't introduce new scopes when they are part of a macro currently :/



from notes, uncategorized
============================
#fuzzy aka cast scoping
for rescue clauses
eg
e = nil
begin
rescue X => e
  # e is "X" here
rescue Y => e
  # e is "Y" here
end
puts e # e is LUB(X, Y)

#behavior literate, exec spec
list o example code + what the compiler says when you give it to the compiler
things like errors, & behavior


fix maven plugins




what I want is to be able to say
this might be a field access,
if a field w/ that name exists on the class, then use it
if it's a constant that's in scope that's not on the current class target, use it

def a
  CONST
end

CONST=1



fixing closures

 add block scope
 block scope
   "self" is captured self
   if in closure self may also be closure type, for method lookup.
   I think this means that the proxy node for calls might need another elem

what's happening is
hit 1st block
look for parent binding, none
create binding for 'm' scope
resolve block type, build closure
hit 2nd block
look for parent binding, walks up to 'm'
but in m's scope y is not captured, so not added to binding


def m           # b = Binding1.new()
  r do          # Closure1.new b; b2 = Binding2.new
    y = 1       # b2.y = 1
    r do        # Closure2.new b2
      y += 4    # b2.y += 4
    end
    puts y
  end
end

update binding/closure generation

one top level binding, 2 closures
def m           # b = Binding1.new()
  x = 1         # b.x = 1
  r do          # Closure1.new b
    x += 1      # b.x += 1
    r do        # Closure2.new b
      x += 4    # b.x += 4
    end
  end
  puts x        # puts b.x
end

one tl binding, one closure binding
def m           # b = Binding1.new()
  x = 1         # b.x = 1
  r do          # Closure1.new b; b2 = Binding2.new
    y = 1       # b2.y = 1
    r do        # Closure2.new b2
      y += 4    # b2.y += 4
    end
    x += y      # b.x += b2.y
  end
  puts x        # puts b.x
end

binding shared across closures
either pull binding construction above 1st ref, or
copy binding back after.
Not sure if I like that
it's probably better to pull binding up, because you don't know when things are run
def m
  x = 1
  r { x += 1 }
  r { x += 2 }
  puts x
end


def m
  x = 1
  l { x += 1 }
  l { x += 2 }
  puts x  # => 1
  run_ls
  puts x  # => 4
end


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

SimpleNodeVisitor sucks. It doesn't seem to work unless you define all the things to visit :(

sometimes implicit nil in return screws everything up, and you get a stack error from the jvm


Hash (things w/ init_list) needs a position, or they blow up w/ NPE somewhere


can't have block args w/ name interface


wierd error for VV
def foo: int
if a < b
end
end




compile rake task doesn't fail, if it doesn't work for some things, it goes on anyway
in generics. hmm
