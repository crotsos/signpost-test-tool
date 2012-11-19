#!/usr/bin/env bash

iodined -n 54.243.31.36 -F /tmp/iodine.pid \
  -P signpost -c -b 5354 \
  "${IP_RANGE}1/24" measure.signpo.st

