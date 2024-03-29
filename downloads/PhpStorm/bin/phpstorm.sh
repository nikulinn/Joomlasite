#!/bin/sh
#
# ---------------------------------------------------------------------
# PhpStorm startup script.
# ---------------------------------------------------------------------
#

UNAME=`which uname`
GREP=`which egrep`
GREP_OPTIONS=""
CUT=`which cut`
READLINK=`which readlink`
MKTEMP=`which mktemp`
RM=`which rm`
CAT=`which cat`
TR=`which tr`
export JDK_HOME=/usr/lib/jvm/java-6-sun
if [ -z "$UNAME" -o -z "$GREP" -o -z "$CUT" -o -z "$MKTEMP" -o -z "$RM" -o -z "$CAT" -o -z "$TR" ]; then
  echo "ERROR: required tools are missing - check beginning of \"$0\" file for details."
  exit 1
fi

OS_TYPE=`"$UNAME" -s`

# ---------------------------------------------------------------------
# Locate a JDK installation directory which will be used to run the IDE.
# Try (in order): WEBIDE_JDK, JDK_HOME, JAVA_HOME, "java" in PATH.
# ---------------------------------------------------------------------
if [ -n "$WEBIDE_JDK" -a -x "$WEBIDE_JDK/bin/java" ]; then
  JDK="$WEBIDE_JDK"
elif [ -n "$JDK_HOME" -a -x "$JDK_HOME/bin/java" ]; then
  JDK="$JDK_HOME"
elif [ -n "$JAVA_HOME" -a -x "$JAVA_HOME/bin/java" ]; then
  JDK="$JAVA_HOME"
else
  JAVA_BIN_PATH=`which java`
  if [ -n "$JAVA_BIN_PATH" ]; then
    if [ "$OS_TYPE" = "FreeBSD" ]; then
      JAVA_LOCATION=`JAVAVM_DRYRUN=yes java | "$GREP" '^JAVA_HOME' | "$CUT" -c11-`
      if [ -x "$JAVA_LOCATION/bin/java" ]; then
        JDK="$JAVA_LOCATION"
      fi
    elif [ "$OS_TYPE" = "SunOS" ]; then
      JAVA_LOCATION="/usr/jdk/latest"
      if [ -x "$JAVA_LOCATION/bin/java" ]; then
        JDK="$JAVA_LOCATION"
      fi
    elif [ "$OS_TYPE" = "Darwin" ]; then
      JAVA_LOCATION=`/usr/libexec/java_home`
      if [ -x "$JAVA_LOCATION/bin/java" ]; then
        JDK="$JAVA_LOCATION"
      fi
    fi

    if [ -z "$JDK" -a -x "$READLINK" ]; then
      JAVA_LOCATION=`"$READLINK" -f "$JAVA_BIN_PATH"`
      case "$JAVA_LOCATION" in
        */jre/bin/java)
          JAVA_LOCATION=`echo "$JAVA_LOCATION" | xargs dirname | xargs dirname | xargs dirname` ;;
        *)
          JAVA_LOCATION=`echo "$JAVA_LOCATION" | xargs dirname | xargs dirname` ;;
      esac
      if [ -x "$JAVA_LOCATION/bin/java" ]; then
        JDK="$JAVA_LOCATION"
      fi
    fi
  fi
fi

if [ -z "$JDK" ]; then
  echo "ERROR: cannot start PhpStorm."
  echo "No JDK found. Please validate either WEBIDE_JDK, JDK_HOME or JAVA_HOME environment variable points to valid JDK installation."
  echo
  echo "Press Enter to continue."
  read IGNORE
  exit 1
fi

VERSION_LOG=`"$MKTEMP" -t java.version.log.XXXXXX`
"$JDK/bin/java" -version 2> "$VERSION_LOG"
"$GREP" 'OpenJDK' "$VERSION_LOG"
OPEN_JDK=$?
"$GREP" "64-Bit|x86_64" "$VERSION_LOG"
BITS=$?
"$RM" -f "$VERSION_LOG"
if [ $OPEN_JDK -eq 0 ]; then
  echo "WARNING: You are launching the IDE using OpenJDK Java runtime."
  echo
  echo "         ITS KNOWN TO HAVE PERFORMANCE AND GRAPHICS ISSUES!"
  echo "         SWITCH TO THE ORACLE(SUN) JDK BEFORE REPORTING PROBLEMS!"
  echo
  echo "NOTE:    If you have both Oracle (Sun) JDK and OpenJDK installed"
  echo "         please validate either WEBIDE_JDK, JDK_HOME, or JAVA_HOME environment variable points to valid Oracle (Sun) JDK installation."
  echo "         See http://ow.ly/6TuKQ for more info on switching default JDK."
  echo
  echo "Press Enter to continue."
# ---------------------------------------------------------------------
# COMMENT LINE BELOW TO REMOVE PAUSE AFTER OPEN JDK WARNING
# ---------------------------------------------------------------------
  read IGNORE
fi
if [ $BITS -eq 0 ]; then
  BITS="64"
else
  BITS=""
fi

# ---------------------------------------------------------------------
# Ensure IDE_HOME points to the directory where the IDE is installed.
# ---------------------------------------------------------------------
SCRIPT_LOCATION=$0
if [ -x "$READLINK" ]; then
  while [ -L "$SCRIPT_LOCATION" ]; do
    SCRIPT_LOCATION=`"$READLINK" -e "$SCRIPT_LOCATION"`
  done
fi

IDE_HOME=`dirname "$SCRIPT_LOCATION"`/..
IDE_BIN_HOME=`dirname "$SCRIPT_LOCATION"`

# ---------------------------------------------------------------------
# Collect JVM options and properties.
# ---------------------------------------------------------------------
if [ -n "$WEBIDE_PROPERTIES" ]; then
  IDE_PROPERTIES_PROPERTY="-Didea.properties.file=\"$WEBIDE_PROPERTIES\""
fi

MAIN_CLASS_NAME="$WEBIDE_MAIN_CLASS_NAME"
if [ -z "$MAIN_CLASS_NAME" ]; then
  MAIN_CLASS_NAME="com.intellij.idea.Main"
fi

VM_OPTIONS_FILE="$WEBIDE_VM_OPTIONS"
if [ -z "$VM_OPTIONS_FILE" ]; then
  VM_OPTIONS_FILE="$IDE_BIN_HOME/phpstorm$BITS.vmoptions"
fi

if [ -r "$VM_OPTIONS_FILE" ]; then
  VM_OPTIONS=`"$CAT" "$VM_OPTIONS_FILE" | "$GREP" -v "^#.*" | "$TR" '\n' ' '`
  VM_OPTIONS="$VM_OPTIONS -Djb.vmOptionsFile=\"$VM_OPTIONS_FILE\""
fi

IS_EAP="false"
if [ "$IS_EAP" = "true" ]; then
  OS_NAME=`echo $OS_TYPE | "$TR" '[:upper:]' '[:lower:]'`
  AGENT_LIB="yjpagent-$OS_NAME$BITS"
  if [ -r "$IDE_BIN_HOME/lib$AGENT_LIB.so" ]; then
    AGENT="-agentlib:$AGENT_LIB=disablej2ee,disablealloc,sessionname=WebIde50"
  fi
fi

COMMON_JVM_ARGS="\"-Xbootclasspath/a:$IDE_HOME/lib/boot.jar\" -Didea.paths.selector=WebIde50 $IDE_PROPERTIES_PROPERTY"
IDE_JVM_ARGS="-Didea.platform.prefix=PhpStorm -Didea.no.jre.check=true"
ALL_JVM_ARGS="$VM_OPTIONS $COMMON_JVM_ARGS $IDE_JVM_ARGS $AGENT $REQUIRED_JVM_ARGS"

CLASSPATH="$IDE_HOME/lib/bootstrap.jar"
CLASSPATH="$CLASSPATH:$IDE_HOME/lib/extensions.jar"
CLASSPATH="$CLASSPATH:$IDE_HOME/lib/util.jar"
CLASSPATH="$CLASSPATH:$IDE_HOME/lib/jdom.jar"
CLASSPATH="$CLASSPATH:$IDE_HOME/lib/log4j.jar"
CLASSPATH="$CLASSPATH:$IDE_HOME/lib/trove4j.jar"
CLASSPATH="$CLASSPATH:$IDE_HOME/lib/jna.jar"
if [ -n "$WEBIDE_CLASSPATH" ]; then
  CLASSPATH="$CLASSPATH:$WEBIDE_CLASSPATH"
fi
export CLASSPATH

LD_LIBRARY_PATH="$IDE_BIN_HOME:$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH

# ---------------------------------------------------------------------
# Run the IDE.
# ---------------------------------------------------------------------
while true ; do
  eval $JDK/bin/java -javaagent:agent.jar=PhpStorm $JVM_ARGS -Djb.restart.code=88 $MAIN_CLASS_NAME $*
  test $? -ne 88 && break
done
