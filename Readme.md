# v8 cross build

This is a set of scripts that can be used to cross-compile the latest
versions of v8 for Ubuntu with system libICU, something that is not
currently possible out of the box.

If it's possible to get some of the changes upstreamed, then this
will become unnecessary.

## Building

```bash
git submodule sync
git submodule update --init
sudo dpkg --add-architecture arm64
sudo dpkg --add-architecture arm
sudo apt-get update
make
```

## Behind the scenes

This does the following
- Checks out depot_tools
- Uses it to install the build dependencies for libv8
- Patches them to allow building with the system libicu not the bundled one
- Installs a cross build root system environment
- Installs the target icu packages for the build
- Builds v8 for all of the architectures
- Copies the libraries and the header files into the output repo

It is primarily used to support mldb.ai, the machine learning database.  This will
only really need to be updated when we move to a new version of v8.
