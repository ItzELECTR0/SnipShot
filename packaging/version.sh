#!/bin/sh
# Prints the package version from the latest v* tag, such as 0.0.1.r2.g085e6ec.
git -C "$(dirname "$0")" describe --long --tags --abbrev=7 --match 'v[0-9]*' | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g'
