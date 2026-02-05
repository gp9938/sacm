# Client Installation

## Overview 
Client installation of a sacm means getting a client, which is a host plus a user login, setup and listening for updates to an app list.

Before installing anything on the client, we first need to create the client repository.  After that we can run the self-installer which will essentially bootstrap the client to get its updates. 

## Setting Up the Client Repository
The client repository, which will reside on your git server follows the following naming convention:

```
        client-<login>-<hostname>
```

This allows there to be multiple instances running on a single host for multiple users.
**Note that rootless Docker support is not yet available**

If creating the git repository directly on a server using the git daemon, create a bare repository like this:
1. `mkdir client-<login>-<hostname>` in the git repo directory
2. `cd client-<login>-<hostname>` into the new directory
3. Create the 'bare' git repository and make it expotable:
  ```
   git --bare init --shared
   touch git-daemon-export-ok
   ```
  

Now clone the repo to your local directory for updating:
```
git clone git://<git-daemon-host>/client-<login>-<hostname>
```

Create the APPS file (can be empty to start)
```
cd client-<login>-<hostname>
touch APPS
```

Now run the `sacm_repo_update.sh` script found in directory `server_side_scripts` with a comment such as `"Initial commit"`:
```
sacm_repo_update.sh "Initial commit"
```

You are now ready to get your client host bootstrapped by installing the client using the `sacm_installer.sh` script found in directory `client_side_scripts` after running `make` or `gmake` in the `client_side_scripts` directory.

Copy `sacm_installer.sh` to your client host.  For example you can use `rsync` to do this:
```
rsync -paurve ssh sacm_installer.sh <usernamer>@<client-host:/var/tmp
```

Run the script as `root` to install it and start the client daemon:
```
sudo bash /var/tmp/sacm_installer.sh
```




