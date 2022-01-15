HUGO_VERSION=0.83.1-asciidoctor
NETLIFY_CLI_VERSION=8.6.23

-include credentials.sh

theme:
	(rm -rf themes && mkdir -p themes)
	(cd themes && git clone https://github.com/pdevty/material-design.git)

build:
	(rm -rf site && mkdir -p site)
	docker run --rm \
		-v $(PWD):/src \
		-v $(PWD)/site:/site \
		-e "HUGO_ENV=production" \
		--entrypoint hugo-official \
		klakegg/hugo:$(HUGO_VERSION) --minify -d /site

serve:
	(rm -rf site && mkdir -p site)
	docker run -it --rm \
		-v $(PWD):/src \
		-v $(PWD)/site:/site \
		-e "HUGO_ENV=dev" \
		--entrypoint hugo-official \
		-p 1313:1313 \
		klakegg/hugo:$(HUGO_VERSION) \
		server --buildDrafts --buildFuture --buildExpired \
		--bind 0.0.0.0 --destination /site

deploy:
	docker run --rm \
		-e NETLIFY_AUTH_TOKEN="$(NETLIFY_AUTH_TOKEN)" \
		-e NETLIFY_SITE_ID="$(NETLIFY_SITE_ID)" \
		-v $(PWD)/site:/project \
		williamjackson/netlify-cli:$(NETLIFY_CLI_VERSION) deploy --prod --dir=/project
