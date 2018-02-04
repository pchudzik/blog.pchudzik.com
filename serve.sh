#!/usr/bin/env bash

docker run \
	--rm \
	-it \
	-v $(pwd):/site \
	-p 1313:1313 \
	hugo serve
