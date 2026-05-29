<!--
SPDX-FileCopyrightText: 2025 Zextras <https://www.zextras.com>

SPDX-License-Identifier: CC0-1.0
-->

# Carbonio Videoserver Third-Party Dependencies

This repository contains the build definitions for third-party libraries required by the Carbonio video server.

The Carbonio video server requires several multimedia and networking libraries that need to be compiled with specific configurations. This repository provides PKGBUILD definitions for building these libraries as Carbonio-specific packages installed under `/opt/zextras/common`.

## Included Libraries

- **x264** - H.264/AVC video encoder
- **libvpx** - VP8/VP9 video codec
- **libopus** - Opus audio codec
- **ffmpeg** - Multimedia framework
- **mlt** - Multimedia framework
- **libsrtp** - Secure Real-time Transport Protocol
- **libnice** - ICE (Interactive Connectivity Establishment) library
- **libusrsctp** - SCTP user-land implementation
- **librabbitmq-c** - RabbitMQ C client

## Quick Start

### Prerequisites

- Docker or Podman installed
- Make

### Building Packages

This project requires third-party dependencies (like `carbonio-openssl`, `carbonio-libxml2`) at build time.

#### For Zextras Developers (with Artifactory access)

Set your Artifactory repository in the container. Dependencies will be fetched automatically from the Zextras Artifactory repositories.

For example, targeting Ubuntu Jammy:

```bash
echo "machine zextras.jfrog.io" >> auth.conf
echo "login $USERNAME" >> auth.conf
echo "password $SECRET" >> auth.conf
mv auth.conf /etc/apt
echo "deb [trusted=yes] https://zextras.jfrog.io/artifactory/ubuntu-devel jammy main" > zextras.list
mv zextras.list /etc/apt/sources.list.d/
```

#### For Community Contributors

First build dependencies from [carbonio-thirds](https://github.com/zextras/carbonio-thirds), then build this project with the `DEPS_DIR` option:

```bash
make build TARGET=ubuntu-jammy DEPS_DIR=../carbonio-thirds/artifacts
```

> **Note**: Use the same `TARGET` (ubuntu-jammy, ubuntu-noble, rocky-8, rocky-9) for both carbonio-thirds and carbonio-videoserver-thirds.

### Supported Targets

- `ubuntu-jammy` - Ubuntu 22.04 LTS
- `ubuntu-noble` - Ubuntu 24.04 LTS
- `rocky-8` - Rocky Linux 8
- `rocky-9` - Rocky Linux 9

### Configuration

You can customize the build by setting environment variables:

```bash
# Use a specific container runtime
make build TARGET=ubuntu-jammy CONTAINER_RUNTIME=docker

# Use a different output directory
make build TARGET=rocky-9 OUTPUT_DIR=./my-packages
```

## Installation

These packages are distributed as part of the [Carbonio platform](https://zextras.com/carbonio). To install:

### Ubuntu (Jammy/Noble)

```bash
apt-get install <package-name>
```

### Rocky Linux (8/9)

```bash
yum install <package-name>
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for information on how to contribute to this project.

## License

This project is licensed under the GNU Affero General Public License v3.0 - see the [LICENSE.md](LICENSE.md) file for details.

Copyright (C) 2024 Zextras <https://www.zextras.com>
