#!/usr/bin/env bash

docker run -it --rm \
	-v $PWD:/src \
	-v $PWD/site:/site \
	-e "HUGO_ENV=dev" \
	--entrypoint hugo-official \
	-p 1313:1313 \
	klakegg/hugo:0.61.0-asciidoctor \
	server --buildDrafts --buildFuture --buildExpired --bind 0.0.0.0 --destination /site
