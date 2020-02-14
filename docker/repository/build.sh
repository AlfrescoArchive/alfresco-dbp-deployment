#!/bin/bash
set -o errexit

. ./build.properties
. ../helpers/common-functions.sh

build_image
