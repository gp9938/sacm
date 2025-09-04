# Getting Started with Simple App Config Manager (sacm)

## Overview
**sacm** has two sides to it: the server side, where configurations are managed and the client side, where the configurations are used.   The server side is really any place where the configs are managed and pushed to the central git repo server (can be github but is just a git daemon server for this manual)

# Pre-requisities
1. A git installation version 2.34 or higher -- 1.8 or higher is probably enough but 1.8 is so old now, it seems odd to say this and I certainly have not tested with it.
2. Bash version 5.1 or greater
3. A way to serve out git repos by network.  This manual is written with the assumption that this will be done using the git daemon and the bare-bones `git://` protocol.  This can also be done with github or with various `https://` based solutions.
4. 3rd-party Docker images you need to manage on your network
5. Docker fully installed on each of your clients.

## Server Side
We will start with the server side, where the configurations will be managed.   This can be the same host that will serve out the configurations via git daemon or other git network solution.   This can also be multiple hosts that a team will use to update these repos.

Currently, there is no server side package to install for Debian, Fedora, etc. so the github repo is what we will use.

Clone the sacm github repo and update your shell `PATH` var to include the `server_side_scripts` directory.

### The Client Repo
A client repo contains the list of apps (Docker containers) that will be deployed to a given client host (by login).  That is, a client repo for host "xyz" and login "root" could have an app list of one item "unbound-rpi" -- a containerized version of the Unbound DNS service for Raspberry Pi. 

There could also be a repo for host "xyz" and login "abcd" with a different list of apps.   They can be managed and operated independently.   **Note that rootless Docker support is not yet available.**




