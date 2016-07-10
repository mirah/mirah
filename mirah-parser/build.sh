ruby -I../mirah/lib:../bitescript/lib ../mirah/bin/mirahc -d build src/org/mirah/ast/meta.mirah
ruby -J-cp build:../mirah/javalib/mirah-bootstrap.jar -I../mirah/lib:../bitescript/lib ../mirah/bin/mirahc -d build src/mirah/lang/ast
mkdir build/mirahparser/impl
java -jar javalib/mmeta.jar --tpl node=src/mirahparser/impl/node.xtm src/mirahparser/impl/Mirah.mmeta build/mirahparser/impl/Mirah.mirah
javac -classpath build:javalib/mmeta-runtime.jar -d build -g src/mirahparser/impl/Tokens.java src/mirahparser/impl/MirahLexer.java
ruby -J-cp build:javalib/mmeta-runtime.jar:../mirah/javalib/mirah-bootstrap.jar -I../mirah/lib:../bitescript/lib ../mirah/bin/mirahc -d build build/mirahparser/impl/Mirah.mirah
