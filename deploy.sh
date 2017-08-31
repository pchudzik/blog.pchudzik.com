#!/usr/bin/env bash

# it requires lftp to be installed and present on $PATH

if [ -d public ]; then
	rm -rf public
fi

hugo

if [ -f credentials.sh ]; then
  source credentials.sh
fi

if [ -z $FTP_USER ] || [ -z $FTP_PASSWORD ]; then
  echo "user or password not set";
  exit 1;
fi

lftp -u $FTP_USER,$FTP_PASSWORD ftp://blog.pchudzik.com -e "set ftp:ssl-allow off; mirror --delete -R public private_html; exit"
