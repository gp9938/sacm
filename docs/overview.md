# Simple App Config Manager (sacm)

## Introduction
Simple App Config Manager (**sacm**) is a very simple management tool for tracking the local configurations of thirdparty docker containers like Unbound or FreshRSS.  It is intended to be used with the various Linux distributions.  As of this writing, it is written entirely in `bash`, both for portability reasons and for the fact that `git` and `Docker` are easiest (for me) to work with as command line tools.

This is a work in progress and I might make major changes.   And yes, there are probably ten or a hundred different ways to automatically manage configurations such as these but I felt Chef, Salt, Puppet, Ansible, and the many open source projects have many dependencies and different respective target use cases.  This is focuses on my current use case and on use the most generally available tools to get it working (e.g. git and bash).

## Features
- Centralized management of third-party Linux Docker images
- Git centric with full git version control
- Generic start, stop, & check scripts that work for many cases
- Custom start, stop, & check scripts optionally available
- Written entirely in bash (v5.1+)
  -  x86 and ARM64 Linux supported
- Support for docker thirdparty (rooted)
- Centralized control of clients running Docker images
    - Client side updates (including sacm) all centrally managed
- Version targeting
    - Each app can be set to use a specific update to its configuration or to just use the latest
    - Versions automatically validated
- No shared dependencies between apps even on a single client (node)
    - Updating the software for one client app, does not affect other client apps
    - Each app has its own copy of the common scripts it depends upon
    - Changes applied on a client only affect the client app that was updated
    - Control of common script library updates is per client (node) per app
- Detailed, timestamped logging of all updates
 

## Concepts
### Server
The server has the git repos for each node (client) and the apps that run on that node.

### Node
A node is a client that has zero or more apps (in containers) running on it.  It obtains its state via remote git to the server

### App
An app is the configured third-party container as it exits within a node (which runs on a host)

### git Server
The git server contains the server node and app repos.  Git servers are currently limited to the git:// protocol supported by the built-in git *daemon*

## Potential Future Improvements
- Support to access git via https:// and ssh://
- Automated bootstrapping of a new client (node)
- Exposed unit test
- Support multiple clients (nodes) per host
- Features to support large numbers of clients (nodes)
    - Support for multiple locations (e.g. datacenters)
- Features to support enterprise change approval workflows
- Support for rootless Docker
- Support for podman
- Repos to allow each client to feedback logs to server (when centralized monitoring is not in place)

## More
[Client Installation](client-installation.md)

