RELEASE MAVEN ARTIFACTS STEPS
=============================

1. Read the OSS Maven guide if you never did it before to know how to set GPG keys and other prerequisites:
   https://docs.sonatype.org/display/Repository/Sonatype+OSS+Maven+Repository+Usage+Guide#SonatypeOSSMavenRepositoryUsageGuide-5.Prerequisites
   http://central.sonatype.org/pages/ossrh-guide.html
2. Bug @calavera if you don't have credentials in the Sonatype repository.
3.  mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/service/local/staging/deploy/maven2/ -DrepositoryId=sonatype-nexus-staging -DpomFile=maven/mirah-complete/pom.xml -Dfile=dist/mirah-complete.jar
    mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/service/local/staging/deploy/maven2/ -DrepositoryId=sonatype-nexus-staging -DpomFile=maven/mirah/pom.xml -Dfile=dist/mirahc.jar
    mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/service/local/staging/deploy/maven2/ -DrepositoryId=sonatype-nexus-staging -DpomFile=pom.xml -Dfile=pom.xml

3 1/2. If you want to publish a snapshot artifact,
    mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/content/repositories/snapshots/ -DrepositoryId=sonatype-nexus-staging -DpomFile=pom.xml -Dfile=pom.xml
    mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/content/repositories/snapshots/ -DrepositoryId=sonatype-nexus-staging -DpomFile=maven/mirah/pom.xml -Dfile=dist/mirahc.jar

4. log into sonatype's oss repo & release the staged build https://oss.sonatype.org/
  a) click on Staging Repositories on the left
  b) sort the list in the main pane by updated time
  c) close the release
  d) ... wait ...
  e) release
  f) If it doesn't work....