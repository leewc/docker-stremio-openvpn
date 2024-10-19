
# docker-stremio-openvpn

Dockerized Stremio with built-in OpenVPN tunneling (similar to haugene's [docker-transmission-openvpn](https://github.com/haugene/docker-transmission-openvpn/tree/master))


## Introduction

[Stremio](https://www.stremio.com/) is a media server and player that supports streaming across multiple protocols with the help of plugins (eg Torrents, RealDebrid). While free and the project claims it is open source, only the players are open source. The core server (backend) is not. 

This container allows you to self host the closed source server code and web UI. Which you can then use the official clients to connect your streaming server to. (Otherwise by default the clients expect the server to also be installed on the same device, leaking your IP).

"Let's run Stremio in a container behind a VPN!" was my thought of why I did this, instead of having to manually set up/turn on VPN every time to use Stremio. It was only after I went through the endeavor did I realize how Stremio actually works. You can skip this section if you know this already or don't care for how it works.

There's 2 components to Stremio.

- `Server.js` -- This is the closed source transpiled Javascript that holds the server. The official release does contain a dockerfile: https://github.com/Stremio/server-docker/blob/main/Dockerfile
 - An interesting thing to note here is there's no actual server code being hosted, it's not open source. The code on Github merely loads it https://github.com/Stremio/server-docker/blob/main/download_server.sh 
 - Usually, for vanilla installs, this runs on the client itself (eg your laptop, mobile phone as an app). It is what is essentially a companion app: https://www.stremio.com/download-service

- `Stremio-web` -- This is the UI/App that most are familiar with: https://github.com/Stremio/stremio-web it is also https://app.strem.io/ and I believe what gets bundled into the Android App. It is a static hosted app, i.e you can simply host bundled files of Stremio-web with any webserver and it'll load all the assets.

This repo hosts both client and server behind a VPN in similar fashion to https://github.com/haugene/docker-transmission-openvpn/ which this repo is based on.
 - The file structure and scripts are intentionally similar to the excellent `docker-transmission-openvpn` by `haugene` to ensure an almost 'drop-in' addition to your docker stack.
 - However, as my server runs on a Rockchip based device, I haven't figured out how to make Jellyfin transcode or leverage GPU (mind you Plex seems to do it out of the box - at least software transcoding). (See Known issues below)

## Getting Started 

How I recommend using this: Set up the *server* and then have your client (your phone/android tv/laptop) point to it and install add ons. This will avoid the app from using it's own locally hosted server at `localhost:11470` and routes all traffic via VPN. The caveat here is your client is still doing searches without the VPN. This way, your client is a true thin-client, the server does most heavy lifting (aside from addons)

When you don't self host, you simply install the companion app, and visit app.strem.io and you're off to the races. When you self host, you can bundle everything into the docker container itself, so your phone doesn't need the app and just visits the webapp.

When you self host, you can either decide to self host the server only, and use an app or do both. In my testing, doing both means your web browser needs to support H264, or the server needs to be smart/powerful enough to transcode, and complexities around GPU hardware/CPU software transcoding will arise.
 - Also, the version available/open source for self hosting is currently v5, which is Beta. It differs from the default v4.4 that is closed source. I found that the v4.4 player (https://app.strem.io/shell-v4.4/) can play more streams in browser than v5 can. I thought it was some jellyfin transcoding issue, but alas it doesn't seem to be it!

### Add-ons

Add-ons are core to the stremio experience, you can find a bunch of add-ons here: https://stremio-addons.netlify.app/ 
 - GitHub: https://github.com/danamag/stremio-addons-list

Here's the fun part. I thought Add-ons were installed server side, but they're not! They're actually installed on the client. Which means, if you install a Stremio App on a device, you have to re-install the addons as they don't persist on the server. The add-ons do things like tell the server what stream to play and how to download the content for streaming.

One way I've found to 'share' add-ons is to simply create a stremio account (not self hosted), which will store your preferences and plugins. There's nothing stopping you from sharing an account with another person if you don't want them to go through the motions of setup, though.

### Already have a reverse proxy?

No separate proxy required if you already have one (e.g Traefik), rather, set Local Network

- https://github.com/haugene/docker-transmission-openvpn/blob/fd609f2ace1970858d3c32fcbd6c271b3d274d39/docs/vpn-networking.md?plain=1#L15

### Can I share the self-hosted server with someone else?

There's no authentication built into stremio server side, so the safest way would be only via a VPN solution like Tailscale, Wireguard, OpenVPN or enabling it only on the local network. I wouldnt' expose this publically as it would allow anyone to stream traffic using your server.

## Known Issues

### HTTPS on Traefik

If you use Traefik as a reverse proxy and do TLS termination on Traefik (eg Let's Encrypt on Traefik), the container starts up the server at a HTTP and HTTPS endpoint. However, as Stremio's `server.js` is closed source, you get a HTTPS error ('could not get a valid HTTPS certificate') if you try and connect to the HTTPS endpoint. I think the HTTPS endpoint only works if you use their generated URL. If you use the HTTP port, Stremio incorrectly assumes and tries to set the 'streaming server URL' as 'http', when it's actually protected by Traefik reverse-proxy. Simple fix, add an `s` to it like so below, and to any settings:

- Incorrect: `https://app.strem.io/shell-v4.4/?streamingServer=http%3A%2F%2Fstremio.example.com#/`
- Correct: `https://app.strem.io/shell-v4.4/?streamingServer=https%3A%2F%2Fstremio.example.com#/`

### No casting devices available

Given this container runs behind OpenVPN and leverages `iptables`, currently haven't figured out how to do Chromecast. However, the simple workaround is to simply install the Stremio app on Chromecast with Google TV or Android device and attempt to cast/play from there.

### NordVPN

While testing I got a weird AES cipher not supported error which went away by selecting another server, seems to be a known issue: https://github.com/haugene/docker-transmission-openvpn/issues/2820 which goes away.

### *fixed* - Path and Home 

The server.js closed source definitely is not used to running on docker and requires a defined environment variable for PATH and HOME. Lack of this results in exceptions being thrown by the compiled `server.js` code. I've fixed this in the container but leaving it here in case someone else finds it useful.

### Non-graceful shutdown

I haven't figured out a bug with the use of `pidof` to get the PID of the running process in the container, currently the container receives a kill signal, but `pidof` results in an empty value. It would appear that some process forking is happening and `dumb-init` or the running user no longer has ability to get the process ID.
The transmission docker container does not have this symptom.

I initially assumed this was due to running as `abc` and not `root` but even running as root the stop script's `pidof` does not work. Directly dropping into the container with `docker exec -it stremio /bin/bash` pidof works fine.

```
stremio  | Sending kill signal to stremio server []
stremio  | Session terminated, killing shell.../etc/stremio/stop.sh: line 16: kill: `': not a pid or valid job spec
stremio  | Sending kill signal to stremio frontend []
stremio  | kill: usage: kill [-s sigspec | -n signum | -sigspec] pid | jobspec ... or kill -l [sigspec]
stremio  | seq: invalid floating point argument: ''
stremio  | Try 'seq --help' for more information.
stremio  | Successfuly closed stremio
stremio  | Fri Oct 18 22:34:19 2024 WARNING: Failed running command (--up/--down): external program exited with error status: 1
stremio  | Fri Oct 18 22:34:19 2024 Exiting due to fatal error
stremio  |  ...killed.
stremio exited with code 1
```

### Hardware Acceleration Not Working

I'm hosting Stremio on a Rockchip device, while I like ARM, nothing ever works without having to screw around with it. https://jellyfin.org/docs/general/administration/hardware-acceleration/rockchip

`docker exec -it stremio /usr/lib/jellyfin-ffmpeg/ffmpeg -v debug -init_hw_device rkmpp=rk -init_hw_device opencl=ocl@rk`

```
ffmpeg version 4.4.1-Jellyfin Copyright (c) 2000-2021 the FFmpeg developers
  built with gcc 8 (Debian 8.3.0-2)
  configuration: --prefix=/usr/lib/jellyfin-ffmpeg --target-os=linux --extra-version=Jellyfin --disable-doc --disable-ffplay --disable-shared --disable-libxcb --disable-sdl2 --disable-xlib --enable-lto --enable-gpl --enable-version3 --enable-static --enable-gmp --enable-gnutls --enable-libdrm --enable-libass --enable-libfreetype --enable-libfribidi --enable-libfontconfig --enable-libbluray --enable-libmp3lame --enable-libopus --enable-libtheora --enable-libvorbis --enable-libdav1d --enable-libwebp --enable-libvpx --enable-libx264 --enable-libx265 --enable-libzvbi --enable-libzimg --toolchain=hardened --enable-cross-compile --arch=arm64 --cross-prefix=/usr/bin/aarch64-linux-gnu-
  libavutil      56. 70.100 / 56. 70.100
  libavcodec     58.134.100 / 58.134.100
  libavformat    58. 76.100 / 58. 76.100
  libavdevice    58. 13.100 / 58. 13.100
  libavfilter     7.110.100 /  7.110.100
  libswscale      5.  9.100 /  5.  9.100
  libswresample   3.  9.100 /  3.  9.100
  libpostproc    55.  9.100 / 55.  9.100
Splitting the commandline.
Reading option '-v' ... matched as option 'v' (set logging level) with argument 'debug'.
Reading option '-init_hw_device' ... matched as option 'init_hw_device' (initialise hardware device) with argument 'rkmpp=rk'.
Reading option '-init_hw_device' ... matched as option 'init_hw_device' (initialise hardware device) with argument 'opencl=ocl@rk'.
Finished splitting the commandline.
Parsing a group of options: global .
Applying option v (set logging level) with argument debug.
Applying option init_hw_device (initialise hardware device) with argument rkmpp=rk.
Invalid device specification "rkmpp=rk": unknown device type
Failed to set value 'rkmpp=rk' for option 'init_hw_device': Invalid argument
Error parsing global options: Invalid argument
```

Still broken :(

I'd ignore the `hls-converter` test failures in the container as well. 

```

stremio  | -> GET /samples/hevc.mkv bytes=0-
stremio  | -> GET /samples/hevc.mkv 
stremio  | Error [ERR_STREAM_PREMATURE_CLOSE]: Premature close
stremio  |     at new NodeError (internal/errors.js:322:7)
stremio  |     at Socket.onclose (internal/streams/end-of-stream.js:121:38)
stremio  |     at Socket.emit (events.js:412:35)
stremio  |     at Socket.emit (domain.js:475:12)
stremio  |     at Pipe.<anonymous> (net.js:686:12) {
stremio  |   code: 'ERR_STREAM_PREMATURE_CLOSE'
stremio  | }
stremio  | -> GET /hlsv2/11470-qsv-linux-video-hevc.mkv/destroy 
stremio  | hls-converter 11470-qsv-linux-video-hevc.mkv has been requested to be destroyed
stremio  | hls-converter 11470-qsv-linux-video-hevc.mkv destoyed
stremio  | hls-converter - Tests failed for [video] hw accel profile: qsv-linux
stremio  | hls-converter - Some tests failed for hw accel profile: qsv-linux
stremio  | hls-converter - Testing video hw accel for profile: nvenc-linux
stremio  | -> GET /hlsv2/11470-nvenc-linux-video-hevc.mkv/video0.m3u8?mediaURL=http%3A%2F%2F127.0.0.1%3A11470%2Fsamples%2Fhevc.mkv&profile=nvenc-linux&maxWidth=1200 
stremio  | hls-converter 11470-qsv-linux-video-hevc.mkv will be destroyed due to passing concurrency of 1
stremio  | -> GET /samples/hevc.mkv 
stremio  | Error [ERR_STREAM_PREMATURE_CLOSE]: Premature close
stremio  |     at new NodeError (internal/errors.js:322:7)
stremio  |     at Socket.onclose (internal/streams/end-of-stream.js:121:38)
stremio  |     at Socket.emit (events.js:412:35)
stremio  |     at Socket.emit (domain.js:475:12)
stremio  |     at Pipe.<anonymous> (net.js:686:12) {
stremio  |   code: 'ERR_STREAM_PREMATURE_CLOSE'
stremio  | }
stremio  | -> GET /hlsv2/11470-nvenc-linux-video-hevc.mkv/destroy 
stremio  | hls-converter 11470-nvenc-linux-video-hevc.mkv has been requested to be destroyed
stremio  | hls-converter 11470-nvenc-linux-video-hevc.mkv destoyed
stremio  | hls-converter - Tests failed for [video] hw accel profile: nvenc-linux
stremio  | hls-converter - Some tests failed for hw accel profile: nvenc-linux
stremio  | hls-converter - Testing video hw accel for profile: vaapi-renderD128
stremio  | -> GET /hlsv2/11470-vaapi-renderD128-video-hevc.mkv/video0.m3u8?mediaURL=http%3A%2F%2F127.0.0.1%3A11470%2Fsamples%2Fhevc.mkv&profile=vaapi-renderD128&maxWidth=1200 
stremio  | hls-converter 11470-nvenc-linux-video-hevc.mkv will be destroyed due to passing concurrency of 1
stremio  | -> GET /samples/hevc.mkv 
stremio  | Error [ERR_STREAM_PREMATURE_CLOSE]: Premature close
stremio  |     at new NodeError (internal/errors.js:322:7)
stremio  |     at Socket.onclose (internal/streams/end-of-stream.js:121:38)
stremio  |     at Socket.emit (events.js:412:35)
stremio  |     at Socket.emit (domain.js:475:12)
stremio  |     at Pipe.<anonymous> (net.js:686:12) {
stremio  |   code: 'ERR_STREAM_PREMATURE_CLOSE'
stremio  | }
stremio  | -> GET /hlsv2/11470-vaapi-renderD128-video-hevc.mkv/destroy 
stremio  | hls-converter 11470-vaapi-renderD128-video-hevc.mkv has been requested to be destroyed
stremio  | hls-converter 11470-vaapi-renderD128-video-hevc.mkv destoyed
stremio  | hls-converter - Tests failed for [video] hw accel profile: vaapi-renderD128
stremio  | hls-converter - Some tests failed for hw accel profile: vaapi-renderD128
```

### *No longer required* Must be run as root in container

Previously the upstream docker image relies on root, I can just use my own image but I don't want to maintain it. However, recently I swapped to my own PUID and PGID and it no longer throws this error. However, if you see the below error, go ahead and set both PUID and PGID to `0`.

```
stremio  | [Error: EACCES: permission denied, unlink '/tmp/v8-compile-cache-0/8.4.371.23-node.88/zSoptzSyarn-v1.22.19zSbinzSyarn.js.BLOB'] {
stremio  |   errno: -13,
stremio  |   code: 'EACCES',
stremio  |   syscall: 'unlink',
stremio  |   path: '/tmp/v8-compile-cache-0/8.4.371.23-node.88/zSoptzSyarn-v1.22.19zSbinzSyarn.js.BLOB'
stremio  | }
stremio  | [Error: EACCES: permission denied, unlink '/tmp/v8-compile-cache-0/8.4.371.23-node.88/zSoptzSyarn-v1.22.19zSbinzSyarn.js.MAP'] {
stremio  |   errno: -13,
stremio  |   code: 'EACCES',
stremio  |   syscall: 'unlink',
stremio  |   path: '/tmp/v8-compile-cache-0/8.4.371.23-node.88/zSoptzSyarn-v1.22.19zSbinzSyarn.js.MAP'
stremio  | }
```

## References and Credits

Other endeavours before me include:
 - https://github.com/psyb0t/safe-stremio
 - https://github.com/elfhosted/containers/blob/main/apps/stremio-server/entrypoint.sh
 - https://github.com/Stremio/server-docker/issues/3
