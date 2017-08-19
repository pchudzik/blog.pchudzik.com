---
title: "Keep your stuff up to date"
Tags: ["mvn", "gradle", "npm"]
Categories: ["best practices", "java", "javascript"]
description: "How to keep external dependencies up to date"
date: "2017-03-30"
---

Every codebase depends on multiple external libraries. It is a good idea to stay up to date with
external dependencies. It is important to update all security related stuff and it might be helpful
or fun to use latest features. I'm going to share my way of staying up to date with external
dependencies in maven, gradle and npm.

<!--more-->

# CI 

The first thing which in my opinion is crucial to stay up to date is to create automated checker.
The best place for this will be your CI tool. Create Jenkins plan (or project in whatever CI tool
you are using) which will fail when there are outdated libraries. Automated tool will nudge you
every time there is an external library that should be updated. Without notification from the CI no
one is going to execute dependency check manually on a day to day development especially when there
is more work than days before the deadline.

I don't recommend failing every time there is outdated library because it will be annoying to update
frontend libraries every second hour ;) Failing when there is more than X outdated libraries is
actually good idea. Just remember to configure X to be an acceptable value. No one is going to
update 15 frontend libraries at once because 4 of them will have different API after bugfix release
(...), but someone might update 2 or 3 of them once in a while.

The last advice which is the game changer I've got is to configure it as commit hook not as
scheduled task. When it is scheduled and it fails in the middle of the night then every developer
will ignore. But when the build fails after your commit then you feel responsible for it and try to
fix it to keep board green ([broken windows
theory](https://en.wikipedia.org/wiki/Broken_windows_theory)).

# npm

When using npm as dependencies manager it is very simple to find out outdated packages - just run
```npm outdated``` ([docs](https://docs.npmjs.com/cli/outdated)) and you are good to go. Sample
outdated command output

{{<highlight text>}}
Package     Current  Wanted  Latest  Location
angular       1.5.9   1.5.9   1.6.3  dependenices-update
lodash        3.6.0   3.6.0  4.17.4  dependenices-update
mocha         3.1.0   3.1.0   3.2.0  dependenices-update
{{</highlight>}}

When you CI instance is configured you might want to create something more 'sophisticated':

{{<highlight bash>}}
#!/bin/sh

npm -s install

MAX_OUTDATED_PACKAGES=$1
OUTDATED_PACKAGES=`npm -s outdated | grep -v beta | grep -v rc`
OUTDATED_PACKAGES_COUNT=`echo "$OUTDATED_PACKAGES" | tail -n +2 | wc -l`

if [ $OUTDATED_PACKAGES_COUNT -ge $MAX_OUTDATED_PACKAGES ]; then
  echo "There is $OUTDATED_PACKAGES_COUNT outdated dependencies!"
  printf '%b\n\n' "$OUTDATED_PACKAGES"
  exit $OUTDATED_PACKAGES_COUNT
fi
{{</highlight>}}

You call this script with a parameter which will be the maximum number of acceptable outdated
dependencies. The script is very simple and will exclude most of the beta and release candidates.

[source](https://github.com/pchudzik/blog-example-dependencies/blob/master/npm/find-outdated-dependencies)

# Gradle

To find outdated dependencies in gradle you can use [gradle versions
plugin](https://github.com/ben-manes/gradle-versions-plugin). Sample output from versions plugin:

{{<highlight text>}}
$> ./gradlew dependencyUpdates

------------------------------------------------------------
: Project Dependency Updates (report to plain text file)
------------------------------------------------------------

The following dependencies are using the latest milestone version:
 - com.github.ben-manes:gradle-versions-plugin:0.14.0

The following dependencies have later milestone versions:
 - org.apache.commons:commons-lang3 [3.4 -> 3.5]
 - junit:junit [3.8.1 -> 4.12]
 - org.springframework:spring-core [3.2.4.RELEASE -> 4.3.7.RELEASE]
{{</highlight>}}

The output is a bit complex, but luckily there are also other formats (JSON and XML) which can be
generated using ```-DoutputFormatter=json``` switch. Output report will be generated in
build/dependencyUpdates directory. Jason support in bash doesn't exists, but you can use
[jq](https://stedolan.github.io/jq/manual/) for working with json in bash (```sudo apt-get install
jq```).

Or you can ask google for some advice on how to use sed and improvise:

{{<highlight shell>}}
#!/bin/sh

./gradlew -DoutputFormatter=json dependencyUpdates > /dev/null 2>&1

MAX_OUTDATED_DEPENDENCIES=$1
REPORT="build/dependencyUpdates/report.txt"
OUDATED_DEPENDENCIES_COUNT=`sed -n -e '/The following dependencies have later/,$p' $REPORT | tail -n +2 | wc -l`

if [ $OUDATED_DEPENDENCIES_COUNT -ge $MAX_OUTDATED_DEPENDENCIES ]; then
  echo "There is $OUDATED_DEPENDENCIES_COUNT outdated dependencies!"
  printf '%b\n\n' "$(cat $REPORT)"
  exit $OUDATED_DEPENDENCIES_COUNT
fi
{{</highlight>}}

Now all you have to do is execute this script with single number param which will be maximum number
of acceptable outdated libraries.

[source](https://github.com/pchudzik/blog-example-dependencies/blob/master/gradle/find-oudated-dependencies)

# mvn

To find outdated libraries using maven you can use [versions-maven-plugin](http://www.mojohaus.org/versions-maven-plugin).
Add versions plugin to your plugins section:

{{<highlight xml>}}
<plugin>
  <groupId>org.codehaus.mojo</groupId>
  <artifactId>versions-maven-plugin</artifactId>
  <version>2.3</version>
</plugin>
{{</highlight>}}

Now you can display outdated packages using ```mvn versions:display-dependency-updates```. If you
want to run this check on CI tool then we need to analyze versions output. Luckily we don't have to
analyze all the stuff that maven produces. We can pass additional property value and save the report
to file. Just run

{{<highlight shell>}}
mvn versions:display-dependency-updates -Dversions.outputFile=target/outdated.txt
{{</highlight>}} 

and versions plugin will plain text file with info what should be updated:

{{<highlight text>}}
The following dependencies in Dependencies have newer versions:
  junit:junit ............................................ 3.8.1 -> 4.12
  org.apache.commons:commons-lang3 .......................... 3.4 -> 3.5
{{</highlight>}}

The output file can be easily verified if there are outdated libraries.

I like to use console for my day to day work, but I hate typing long commands so let's wrap it up
into a single reusable script which can be used on CI:

{{<highlight shell>}}
#!/bin/sh

MAX_OUTDATED_LIBRARIES=$1

OUTPUT="target/outdated.txt"
mkdir -p target

./mvnw -q versions:display-dependency-updates -Dversions.outputFile="$OUTPUT" 

OUTDATED_LIBRARIES=`grep . "$OUTPUT" | tail -n +2 | wc -l`

if [ $OUTDATED_LIBRARIES -ge $MAX_OUTDATED_LIBRARIES ]; then
  echo "There is $OUTDATED_LIBRARIES outdated libraries!\n"
  printf '%b\n\n' "$(cat target/outdated.txt)"
  exit $OUTDATED_LIBRARIES
fi
{{</highlight>}}

As in previous examples to run script you must provide single argument which will be maximum number
of acceptable outdated libraries

When using maven and versions plugin there are also additional targets you can execute (including
site report generation and finding outdated plugins). Checkout
[documentation](http://www.mojohaus.org/versions-maven-plugin/plugin-info.html) for more details.

[source](https://github.com/pchudzik/blog-example-dependencies/blob/master/mvn/find-outdated-dependencies)
