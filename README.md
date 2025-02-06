# Simple App Config Manager (sacm)

## Introduction
This is a very simple management tool for managing the local configurations of thirdparty docker containers like Unbound or FreshRSS.  It is written entirely in bash (as of this writing).  This is both for portability reasons and for the fact that git and Docker are easiest (for me) to work with as command line tools.

This is a work in progress and I might make major changes.   And yes, there are probably ten or a hundred different ways to automatically manage configurations such as these but I felt Chef, Salt, Puppet, Ansible, and the like have many dependencies and by focusing on bash and git, it would be easy to get this working and debugged.

## Basics
