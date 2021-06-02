#!/bin/bash

set -e

echo "Started with args"

client_version_env="$client_version_env" #We should pick this from the jar not as an argument.
crypto_key_env="$crypto_key_env" #key to encrypt the jar files
client_certificate="$client_certificate_env" # Not used as of now
client_upgrade_server="$client_upgrade_server_env" #docker hosted url
reg_client_sdk_url="$reg_client_sdk_url_env"
artifactory_url="$artifactory_url_env"

echo "initalized variables"

mkdir -p /registration-libs/target/props

echo "mosip.reg.app.key=${crypto_key_env}" > /registration-libs/target/props/mosip-application.properties
echo "mosip.reg.version=${client_version_env}" >> /registration-libs/target/props/mosip-application.properties
echo "mosip.reg.client.url=${client_upgrade_server}/registration-client/" >> /registration-libs/target/props/mosip-application.properties
echo "mosip.reg.healthcheck.url=${healthcheck_url_env}" >> /registration-libs/target/props/mosip-application.properties
echo "mosip.reg.rollback.path=../BackUp" >> /registration-libs/target/props/mosip-application.properties
echo "mosip.reg.cerpath=/cer/mosip_cer.cer" >> /registration-libs/target/props/mosip-application.properties
echo "mosip.reg.dbpath=db/reg" >> /registration-libs/target/props/mosip-application.properties
echo "mosip.reg.xml.file.url=${client_upgrade_server}/registration-client/maven-metadata.xml" >> /registration-libs/target/props/mosip-application.properties
echo "mosip.reg.client.tpm.availability=Y" >> /registration-libs/target/props/mosip-application.properties
echo "mosip.client.upgrade.server.url=${client_upgrade_server}" >> /registration-libs/target/props/mosip-application.properties

echo "created mosip-application.properties"

cd /registration-libs/target
jar uf registration-libs-${client_version_env}.jar props/mosip-application.properties
cd /

if wget "${artifactory_url}/artifactory/libs-release-local/reg-client/resources.zip"
then
  echo "Successfully downloaded reg-client resources, Adding it to reg-client jar"
  /usr/bin/unzip /resources.zip
  cd /resources
  jar uvf /registration-client/target/registration-client-${client_version_env}.jar .
else
  echo "No separate resources found !!"
fi

cd /
mkdir -p /sdkjars

if [ "$reg_client_sdk_url" ]
then
	echo "Found thirdparty SDK"
	wget "$reg_client_sdk_url"
	/usr/bin/unzip /sdkDependency.zip
	cp /sdkDependency/*.jar /registration-client/target/lib/
else
	echo "Downloading MOCK SDK..."
	wget "${artifactory_url}/artifactory/libs-release-local/mock-sdk/1.1.5/mock-sdk.jar" -O /registration-client/target/lib/mock-sdk.jar
fi


wget "${artifactory_url}/artifactory/libs-release-local/icu4j/icu4j.jar" -O /registration-client/target/lib/icu4j.jar
wget "${artifactory_url}/artifactory/libs-release-local/icu4j/kernel-transliteration-icu4j.jar" -O /registration-client/target/lib/kernel-transliteration-icu4j.jar
wget "${artifactory_url}/artifactory/libs-release-local/clamav/clamav.jar" -O /registration-client/target/lib/clamav.jar
wget "${artifactory_url}/artifactory/libs-release-local/clamav/kernel-virusscanner-clamav.jar" -O /registration-client/target/lib/kernel-virusscanner-clamav.jar

#unzip Jre to be bundled
/usr/bin/unzip /zulu11.41.23-ca-fx-jre11.0.8-win_x64.zip
mkdir -p /registration-libs/resources/jre
mv /zulu11.41.23-ca-fx-jre11.0.8-win_x64/* /registration-libs/resources/jre/
chmod -R a+x /registration-libs/resources/jre

/usr/local/openjdk-11/bin/java -cp /registration-libs/target/*:/registration-client/target/lib/* io.mosip.registration.cipher.ClientJarEncryption "/registration-client/target/registration-client-${client_version_env}.jar" "${crypto_key_env}" "${client_version_env}" "/registration-libs/target/" "/build_files/${client_certificate}" "/registration-libs/resources/db/reg" "/registration-client/target/registration-client-${client_version_env}.jar" "/registration-libs/resources/rxtx" "/registration-libs/resources/jre" "/registration-libs/resources/batch/run.bat" "/registration-libs/target/props/mosip-application.properties"

echo "encryption completed"

cd /registration-client/target/
mv "mosip-sw-${client_version_env}.zip" reg-client.zip
mkdir -p /registration-client/target/bin
cp /registration-client/target/lib/mosip-client.jar /registration-client/target/bin/
cp /registration-client/target/lib/mosip-services.jar /registration-client/target/bin/

ls -ltr lib | grep bc

/usr/bin/zip -r reg-client.zip bin
/usr/bin/zip -r reg-client.zip lib

## adding logback.xml
/usr/bin/zip -j reg-client.zip /build_files/logback.xml
#/usr/bin/zip reg-client.zip MANIFEST.MF

#Creating Regclient testing framework
mkdir -p /registration-test-utility
mkdir -p /registration-test-utility/lib
cp /registration-test/target/registration-test-*-dependencies.jar /registration-test-utility/registration-test.jar
cp /registration-test/resources/*  /registration-test-utility/
cp -r /registration-libs/resources/jre /registration-test-utility/
cp -r /registration-client/target/lib/morena* /registration-test-utility/lib
cp -r /sdkjars/*.jar /registration-test-utility/lib
cp /registration-client/target/MANIFEST.MF /registration-test-utility/
/usr/bin/zip -r /registration-test-utility.zip /registration-test-utility

echo "setting up nginx static content"

mkdir -p /var/www/html/registration-client
mkdir -p /var/www/html/registration-client/${client_version_env}
mkdir -p /var/www/html/registration-client/${client_version_env}/lib
mkdir -p /var/www/html/registration-test/${client_version_env}

cp /registration-client/target/lib/* /var/www/html/registration-client/${client_version_env}/lib
cp /registration-client/target/MANIFEST.MF /var/www/html/registration-client/${client_version_env}/
cp /build_files/maven-metadata.xml /var/www/html/registration-client/
cp reg-client.zip /var/www/html/registration-client/${client_version_env}/
cp /registration-test-utility.zip /var/www/html/registration-test/${client_version_env}/

echo "setting up nginx static content - completed"

/usr/sbin/nginx -g "daemon off;"
