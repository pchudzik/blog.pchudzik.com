# blog.pchudzik.com

Sources for [my blog](http://blog.pchudzik.com)

It's powered by [hugo](http://gohugo.io)

![](https://github.com/pchudzik/blog.pchudzik.com/workflows/deploy/badge.svg)
[![Netlify Status](https://api.netlify.com/api/v1/badges/d6f6dbe3-e9de-4dd8-83cc-a7ebe9f7249d/deploy-status)](https://app.netlify.com/sites/blog-pchudzik-com/deploys)

## Development

### Setup

```make theme```

### Serve built files

```
make serve
```

Google analytics will be disabled when serving files locally. To enable it environment variable
`HUGO_ENV=production` must be defined (passed to docker image building serving site).

### Deploy site

Deployment is automatically executed when commit is pushed on master branch. It can be triggered
manually using:

```
make deploy
```
