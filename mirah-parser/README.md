Mirah Parser
===============
[![Build Status](https://secure.travis-ci.org/mirah/mirah-parser.png)](http://travis-ci.org/mirah/mirah-parser)

The parser used for [Mirah](https://github.com/mirah/mirah).  

##License 

Apache 2.0

##Build Instructions

1. Copy mirah.jar and mirahc.jar from a working Mirah distribution into the javalib directory.
2. `rake test`

### Adding Parser into the Mirah Project

Once you have built the parser, you will have a `mirah-parser.jar` file inside the `dist` directory.  Just copy this file into the `javalib` directory of the your mirah project, and the build it.