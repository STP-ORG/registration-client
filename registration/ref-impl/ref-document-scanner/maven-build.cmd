call mvn install:install-file -Dfile=${project.basedir}/lib/morena7.jar -DgroupId=morena7 -DartifactId=morena7 -Dversion=1.0 -Dpackaging=jar -DgeneratePom=true
call mvn install:install-file -Dfile=${project.basedir}/lib/morena_license.jar -DgroupId=morena7-license -DartifactId=morena7-license -Dversion=1.0 -Dpackaging=jar -DgeneratePom=true
call mvn install:install-file -Dfile=${project.basedir}/lib/morena7_win.jar -DgroupId=morena7-win -DartifactId=morena7-win -Dversion=1.0 -Dpackaging=jar -DgeneratePom=true
call mvn clean install -Dgpg.skip=true -Dmaven.test.skip=true