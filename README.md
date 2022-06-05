<p align="center"><a href="https://github.com/crazy-max/docker-unbound" target="_blank"><img height="128" src="https://raw.githubusercontent.com/crazy-max/docker-unbound/master/.github/docker-unbound.jpg"></a></p>

<p align="center">
  <a href="https://hub.docker.com/r/crazymax/unbound/tags?page=1&ordering=last_updated"><img src="https://img.shields.io/github/v/tag/crazy-max/docker-unbound?label=version&style=flat-square" alt="Latest Version"></a>
  <a href="https://github.com/crazy-max/docker-unbound/actions?workflow=build"><img src="https://img.shields.io/github/workflow/status/crazy-max/docker-unbound/build?label=build&logo=github&style=flat-square" alt="Build Status"></a>
  <a href="https://hub.docker.com/r/crazymax/unbound/"><img src="https://img.shields.io/docker/stars/crazymax/unbound.svg?style=flat-square&logo=docker" alt="Docker Stars"></a>
  <a href="https://hub.docker.com/r/crazymax/unbound/"><img src="https://img.shields.io/docker/pulls/crazymax/unbound.svg?style=flat-square&logo=docker" alt="Docker Pulls"></a>
  <br /><a href="https://github.com/sponsors/crazy-max"><img src="https://img.shields.io/badge/sponsor-crazy--max-181717.svg?logo=github&style=flat-square" alt="Become a sponsor"></a>
  <a href="https://www.paypal.me/crazyws"><img src="https://img.shields.io/badge/donate-paypal-00457c.svg?logo=paypal&style=flat-square" alt="Donate Paypal"></a>
</p>

## About

Docker image for [Unbound](https://unbound.net/), a validating, recursive, and caching DNS resolver.<br />
If you are interested, [check out](https://hub.docker.com/r/crazymax/) my other Docker images!

💡 Want to be notified of new releases? Check out 🔔 [Diun (Docker Image Update Notifier)](https://github.com/crazy-max/diun) project!

___

* [Features](#features)
* [Build locally](#build-locally)
* [Image](#image)
* [Ports](#ports)
* [Usage](#usage)
  * [Docker Compose](#docker-compose)
  * [Command line](#command-line)
* [Upgrade](#upgrade)
* [Notes](#notes)
  * [Configuration](#configuration)
  * [Root trust store](#root-trust-store)
* [Contributing](#contributing)
* [License](#license)

## Features

* Run as non-root user
* Latest [Unbound](https://nlnetlabs.nl/projects/unbound/download/) release compiled from source
* Bind to [unprivileged port](#ports)
* Multi-platform image

## Build locally

```shell
git clone https://github.com/crazy-max/docker-unbound.git
cd docker-unbound

# Build image and output to docker (default)
docker buildx bake

# Build multi-platform image
docker buildx bake image-all
```

## Image

| Registry                                                                                         | Image                           |
|--------------------------------------------------------------------------------------------------|---------------------------------|
| [Docker Hub](https://hub.docker.com/r/crazymax/unbound/)                                            | `crazymax/unbound`           |
| [GitHub Container Registry](https://github.com/users/crazy-max/packages/container/package/unbound)  | `ghcr.io/crazy-max/unbound`  |

Following platforms for this image are available:

```
$ docker run --rm mplatform/mquery crazymax/unbound:latest
Image: crazymax/unbound:latest
 * Manifest List: Yes
 * Supported platforms:
   - linux/amd64
   - linux/arm/v6
   - linux/arm/v7
   - linux/arm64
   - linux/ppc64le
   - linux/s390x
```

## Volumes

* `/config`: Additional [configuration](#configuration) files

## Ports

* `5053/tcp 5053/udp`: DNS listening port

## Usage

### Docker Compose

Docker compose is the recommended way to run this image. You can use the following
[docker compose template](examples/compose/docker-compose.yml), then run the container:

```shell
docker-compose up -d
docker-compose logs -f
```

### Command line

You can also use the following minimal command:

```shell
docker run -d -p 5053:5053 --name unbound crazymax/unbound
```

## Upgrade

Recreate the container whenever I push an update:

```shell
docker-compose pull
docker-compose up -d
```

## Notes

### Configuration

When Unbound is started the main configuration [/etc/unbound/unbound.conf](rootfs/etc/unbound/unbound.conf)
is imported.

If you want to override settings from the main configuration you have to create config files
(with `.conf` extension) in `/config` volume.

You can also setup [forwarding queries](https://nlnetlabs.nl/documentation/unbound/unbound.conf/#forward-host)
to the appropriate public DNS server for queries that cannot be answered by this server using a new ocnfiguration
called `/config/forward-records.conf`:

```text
forward-zone:
  name: "."
  forward-tls-upstream: yes

  # cloudflare-dns.com
  forward-addr: 1.1.1.1@853
  forward-addr: 1.0.0.1@853
  #forward-addr: 2606:4700:4700::1111@853
  #forward-addr: 2606:4700:4700::1001@853
```

A complete documentation about Ubound configuration can be found on
NLnet Labs website: https://nlnetlabs.nl/documentation/unbound/unbound.conf/

> ⚠️ Container has to be restarted to propagate changes

### Root trust store

This image already embeds a root trust anchor to perform DNSSEC validation.

If you want to generate a new key, you can use [`unbound-anchor`](https://nlnetlabs.nl/documentation/unbound/unbound-anchor/)
which is available in this image:

```shell
docker run -t --rm --entrypoint "" -v "$(pwd):/trust-anchor" crazymax/unbound:latest \
  unbound-anchor -v -a "/trust-anchor/root.key"
```

If you want to use your own root trust anchor, you can create a new config file
called for example `/config/00-trust-anchor.conf`:

```text
  auto-trust-anchor-file: "/root.key"
```

> See [documentation](https://nlnetlabs.nl/documentation/unbound/unbound.conf/#auto-trust-anchor-file) for more info
> about `auto-trust-anchor-file` setting.

And bind mount the key:

```yaml
version: "3.7"

services:
  unbound:
    image: crazymax/unbound
    container_name: unbound
    ports:
      - target: 5053
        published: 5053
        protocol: tcp
      - target: 5053
        published: 5053
        protocol: udp
    volumes:
      - "./config:/config"
      - "./root.key:/root.key"
    restart: always
```

## Contributing

Want to contribute? Awesome! The most basic way to show your support is to star the project, or to raise issues. You
can also support this project by [**becoming a sponsor on GitHub**](https://github.com/sponsors/crazy-max) or by making
a [Paypal donation](https://www.paypal.me/crazyws) to ensure this journey continues indefinitely!

Thanks again for your support, it is much appreciated! :pray:

## License

MIT. See `LICENSE` for more details.
