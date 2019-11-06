#!/usr/bin/env bash

docker run \
	--rm \
	-it \
	-e "HUGO_ENV=development" \
	-v $(pwd):/site \
	-p 1313:1313 \
	hugo serve
