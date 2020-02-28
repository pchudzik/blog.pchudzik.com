#!/usr/bin/env bash

cat $1 | docker run --rm -i think/plantuml -tpng
