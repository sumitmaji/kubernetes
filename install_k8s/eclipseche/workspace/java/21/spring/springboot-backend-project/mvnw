#!/bin/sh
# ----------------------------------------------------------------------------
# Apache Maven
# Version: 3.8.1
# ----------------------------------------------------------------------------

MAVEN_HOME="$(dirname "$0")/maven"
if [ -d "$MAVEN_HOME" ]; then
  exec "$MAVEN_HOME/bin/mvn" "$@"
else
  echo "Maven not found. Please install Maven or set MAVEN_HOME."
  exit 1
fi