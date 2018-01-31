# blog.pchudzik.com
Sources for [my blog](http://blog.pchudzik.com)

It's powered by [hugo](http://gohugo.io)

## Docker

### build docker

```
docker build -t hugo .
```

### serve built files

```
docker run -it --rm -v "$(pwd):/site" -p 1313:1313 hugo serve
```

### build site for deployment

```
docker run -it --rm -v "$(pwd):/site" hugo build
```

### deploy site

```
docker run --rm -it -e FTP_USER=put-user-here -e FTP_PASSWORD=put-password-here -v "$(pwd):/site" hugo deploy
```

### get build site from docker image

Built files will be in dist directory

```
mkdir dist && docker run -it --rm -v "$(pwd)/dist:/dist" -v "$(pwd):/site" hugo build
```
