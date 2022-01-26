#!/usr/bin/env bash

cp -- /tmp/src/conf/ocp/logback.xml "$CONF_DIR/logback.xml"
# There are normally two configurations: core and environment
cp -- /tmp/src/conf/ds-present-*.yaml "$CONF_DIR/"
 
ln -s -- "$TOMCAT_APPS/ds-present.xml" "$DEPLOYMENT_DESC_DIR/ds-present.xml"
