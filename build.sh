#!/bin/sh
set -xe
odin build . -error-pos-style:unix -show-timings -debug -use-separate-modules -thread-count:1
