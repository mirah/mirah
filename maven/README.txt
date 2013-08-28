RELEASE MAVEN ARTIFACTS STEPS
=============================

1. Read the OSS Maven guide if you never did it before to know how to set GPG keys and other prerequisites:
   https://docs.sonatype.org/display/Repository/Sonatype+OSS+Maven+Repository+Usage+Guide#SonatypeOSSMavenRepositoryUsageGuide-5.Prerequisites
2. Bug @calavera if you don't have credentials in the Sonatype repository.
3.  mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/service/local/staging/deploy/maven2/ -DrepositoryId=sonatype-nexus-staging -DpomFile=maven/mirah-complete/pom.xml -Dfile=dist/mirah-complete-*.jar
    mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/service/local/staging/deploy/maven2/ -DrepositoryId=sonatype-nexus-staging -DpomFile=maven/mirah/pom.xml -Dfile=dist/mirah*.jar
    mvn gpg:sign-and-deploy-file -Durl=https://oss.sonatype.org/service/local/staging/deploy/maven2/ -DrepositoryId=sonatype-nexus-staging -DpomFile=pom.xml -Dfile=pom.xml


4. log into sonatype's oss repo & release the staged build
