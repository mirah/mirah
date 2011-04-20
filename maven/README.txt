RELEASE MAVEN ARTIFACTS STEPS
=============================

1. Read the OSS Maven guide if you never did it before to know how to set GPG keys and other prerequisites:
   https://docs.sonatype.org/display/Repository/Sonatype+OSS+Maven+Repository+Usage+Guide#SonatypeOSSMavenRepositoryUsageGuide-5.Prerequisites
2. Bug @calavera if you don't have credentials in the Sonatype repository.
3. execute `mvn release:prepare`. It creates a tag for the new release and sets version numbers.
4. execute `cd target && ln -s ../../bitescript bitescript`. The final release process needs the bitescript project accesible.
5. execute `mvn release:perform`
