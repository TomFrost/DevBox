# DevBox
A minimal bootstrapper to turn a brand new Mac into a docker-based dev environment

## Installation
To get up and running without cloning the repo:

```
sh <(curl -fsSL https://rawgit.com/TechnologyAdvice/devbox/master/install/mac_install.sh)
```

## Who is this for?
DevBox was created to standardize development config at [TechnologyAdvice](http://www.technologyadvice.com), but nothing this script does is company-specific. If you're looking for a great baseline for getting started with Docker-based development on a Mac, DevBox might be a good place to start.

## What does it do?
After a successful run, the Mac will have an active, super performant Docker environment. A Docker VM is installed into macOS's native hypervisor (xhyve), and the `/Users` folder is mounted on it via a local NFS share -- the fastest measured way to mount Docker volumes on a Mac. The VM is also outfitted with [FS-EventStream](https://github.com/TechnologyAdvice/fs_eventstream) to allow a client on the Mac to forward file change events into the VM. This allows applications like webpack, gulp, nodemon, and any other inotify listener to see when files change on the host. This VM will be autostarted every time the Mac is booted, with the help of a lunch agent installed in `~/Library/LaunchAgents`.

In addition, DevBox installs [DevLab](https://github.com/TechnologyAdvice/DevLab), a docker-compose alternative with built-in FS-EventStream support, which also exposes any container-exposed ports on localhost for the full just-like-Linux experience.

Some other software is installed to support the above. That includes:
- [Homebrew](http://brew.sh)
- [Node.js](http://nodejs.org)
- docker-machine
- [docker-machine-nfs](https://github.com/adlogix/docker-machine-nfs)
- tmux (necessary to start xhyve on boot)

Note that all software installs are idempotent. For example, if you've already downloaded and installed the official Node.js package from their website, DevBox won't install it again from brew.

## Why not use the new Docker for Mac?
[Docker for Mac](https://docs.docker.com/docker-for-mac/) was recently released by the Docker team to automate the process of running Docker inside of xhyve on Mac. At the moment, Docker for Mac does not cover the full scope of development use cases due to various bugs and performance issues, particularly with the [problems in osxfs](https://forums.docker.com/t/file-access-in-mounted-volumes-extremely-slow-cpu-bound/8076) that cause some filesystem-heavy operations to take minutes rather than seconds. DevBox automatically creates a very similar environment, but mounts volumes using the more performant NFS, forwarding fsevents out-of-band.

## How can I configure it?
DevBox is just a shell script, so feel free to fork it and modify it for your own needs! Out of the box, you can change the docker-machine name by setting the `MACHINE_NAME` environment variable before running the script (default is devbox). Also by default, new files created within the VM/container volumes will be owned by your Mac user. For a native Linux experience, edit /etc/exports to remove the `-mapall=501:20` argument.

## License
DevBox is ISC licensed. See details in LICENSE.txt.

## Credits
DevBox was created by Tom Shawver at TechnologyAdvice in 2016.

