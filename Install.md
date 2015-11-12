# Requirements #

You will need:

  * [Gcc 4.6](http://gcc.gnu.org) or [GNAT GPL 2013](http://libre.adacore.com/libre/download/)
  * [Ada Util 1.7](http://code.google.com/p/ada-util)

# Build #

Build with the following commands:

```
   ./configure
   make
```

The samples can be built using:
```
   gnatmake -Psamples
```

# Tests #

The unit tests are built using:
```
   gnatmake -Ptests
```

And unit tests are executed with:

```
   bin/el_harness
```

The makefile can be used to build and run the tests with:
```
   make test
```

# Installation #

The installation on Ubuntu or Debian-based system is possible by using
the **install** target:
```
   sudo make install
```