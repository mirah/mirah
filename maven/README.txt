RELEASE MAVEN ARTIFACTS STEPS
=============================

1. Read the OSS Maven guide if you never did it before to know how to set GPG keys and other prerequisites:
   https://docs.sonatype.org/display/Repository/Sonatype+OSS+Maven+Repository+Usage+Guide#SonatypeOSSMavenRepositoryUsageGuide-5.Prerequisites
2. Bug @calavera if you don't have credentials in the Sonatype repository.
3. make sure the pom.xml files (pom.xml, maven/mirah/pom.xml,
   maven/mirah-complete/pom.xml) are at the expected version.
4. check the versions again.
5. run maven deploy. That will build the artifacts and push them up to
   the repo. 
