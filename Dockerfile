FROM debian:8.10

LABEL maintainer="pawel.chudzik@gmail.com"

RUN apt-get update
RUN apt-get -q -y install wget lftp
RUN apt-get -q -y install asciidoctor

WORKDIR /tmp
RUN wget -q -O hugo.tar.gz https://github.com/gohugoio/hugo/releases/download/v0.53/hugo_0.53_Linux-64bit.tar.gz
RUN tar xf hugo.tar.gz
RUN mv hugo /bin/


RUN mkdir /dist

RUN echo '#!/bin/sh \n\
rm -rf /dist/*' > /bin/cleanup

RUN echo '#!/bin/sh \n\
/bin/cleanup \n\
/bin/hugo serve --bind 0.0.0.0 -D -F -E -d /dist \n' > /bin/serve

RUN echo '#!/bin/sh \n\
/bin/cleanup \n\
/bin/hugo -d /dist\n' > /bin/build

RUN echo '#!/bin/sh \n\
/bin/cleanup \n\
/bin/build \n\
lftp \
	-u $FTP_USER,$FTP_PASSWORD \
	ftp://blog.pchudzik.com \
	-e "set ftp:ssl-allow off; \
		mirror \
			--delete -R --depth-first --parallel=4 -v \
			/dist private_html; exit"' > /bin/deploy

RUN chmod +x \
	/bin/serve \
	/bin/build \
	/bin/cleanup \
	/bin/deploy

WORKDIR /site

EXPOSE 1313
VOLUME /site
VOLUME /dist
