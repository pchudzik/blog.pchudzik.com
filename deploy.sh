#!/usr/bin/env bash

set -e

if [ -f credentials.sh ]; then
	. ./credentials.sh
fi

docker run --rm \
	-v $PWD:/src \
	-v $PWD/site:/site \
	-e "HUGO_ENV=production" \
	--entrypoint hugo-official \
	klakegg/hugo:0.64.1-asciidoctor --minify -d /site

sudo chmod -R 777 site

docker run --rm \
	-e NETLIFY_AUTH_TOKEN="$NETLIFY_AUTH_TOKEN" \
	-e NETLIFY_SITE_ID="$NETLIFY_SITE_ID" \
	-v $PWD/site:/project \
	williamjackson/netlify-cli:2.32.0 deploy --prod --dir=/project
