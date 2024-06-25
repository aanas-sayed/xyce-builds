Xyce Build Scipts
=================

Scripts to build and install Xyce onto Debian with parallel simulatons enabled.

.. Note: Only contains parallel builds at the moment as no real benefit of 
having the serial build at the moment.

Usage
------------

For Debian operating systems, without an x-server, run `linux_debian_*.sh` as 
root. This will run the script in the shell and the shell cannot be closed. 
To run it, detached from the shell, you can add the `--detached` or `-d`.
```
sudo ./linux_debian_*.sh [--detached -d]
```
If run as detached, the process ID will be printed out before detaching. The 
varibale XYCE_INSTALL_PID should also be **temporarily** available which will 
store the ID. To kill the installation procces use:
```
kill -0 $XYCE_INSTALL_PID
```

For Debian operating systems, with an x-server, run `linux_debian_xserver_*.sh` 
as root. This can be run the same way as `linux_debian_*.sh` and it does 
everything the same way. It only adds the possibility for the user to be 
notified via system notifications if the build/installation completes or fails 
when run detached.

These scripts will create log file in the current working directory 
when run detached. Xyce will be built and installed in the following 
directories: `/opt/XyceLibs/Parallel` and `/opt/Xyce/Parallel` for the parallel 
build (serial build script not added yet).
    