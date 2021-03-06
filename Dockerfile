# FROM oracle/graalvm-ce:20.1.0-java11 as graalvm
FROM oracle/graalvm-ce:20.2.0-java8 as graalvm

RUN gu install native-image

# early version, works with java9 jmods
RUN curl https://maven.repository.redhat.com/earlyaccess/all/org/eclipse/jdt/core/compiler/ecj/maven-metadata.xml \
	| grep -oPm1 "(?<=<latest>)[^<]+" > ECJ_VERSION

RUN curl https://maven.repository.redhat.com/earlyaccess/all/org/eclipse/jdt/core/compiler/ecj/$(cat ECJ_VERSION)/ecj-$(cat ECJ_VERSION).jar -o ecj.jar

RUN mkdir META-INF/native-image -p

COPY hello.java /

# to generate reflect-config.json, resource-config.json ...
RUN java -agentlib:native-image-agent=config-output-dir=META-INF/native-image -jar ecj.jar hello.java -verbose -1.8 

RUN native-image --initialize-at-build-time=org.eclipse.jdt.internal.compiler \
	 --initialize-at-run-time=org.eclipse.jdt.internal.compiler.apt.model.ElementsImpl9 \
	-jar ecj.jar  --no-server --no-fallback \
	-H:ResourceConfigurationFiles=META-INF/native-image/resource-config.json \
	-H:ReflectionConfigurationFiles=META-INF/native-image/reflect-config.json --static \
	-H:Name=ecj-native --allow-incomplete-classpath

# --libc=musl can only be used with java11
# rt.jar for compilation could only be found in java8
# counter part for java11 is found in java 11 but in jmods, needs some research

FROM alpine

COPY --from=graalvm /ecj-native /app/ecj-native

COPY --from=graalvm /opt/graalvm-ce-java8-20.2.0/jre/lib/rt.jar /app/rt.jar

CMD ["/app/ecj-native"]
