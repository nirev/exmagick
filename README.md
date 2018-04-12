ExMagick
========

USAGE
-----

```elixir
defp deps do
  [{:exmagick, "~> 0.0.1"}]
end
```

DEPENDENCIES
------------

### Linux ###

* `libtool`
* `c compiler`
* `graphicsmagick`

#### Example: Arch Linux ####

```bash
$ pacman -S gcc make libtool graphicsmagick
```

#### Example: Debian ####

```bash
$ apt-get install gcc make libtool-bin libgraphicsmagick1-dev
```

OSX:

```bash
$ brew install libtool
$ brew install graphicsmagick
```

INSTALLING
----------

If you have all dependencies satisfied then the following should pass:

```
$ mix test
```

DIRTY SCHEDULER
---------------

The library has support for using dirty scheduler but it is disabled
by default. To enable it, define an environment variable before
compiling:

```
$ env exm_dirty_sched=auto mix compile
```

It will enable dirty scheduler support when the machine provides
support for it.

LINKS
-----

* http://www.graphicsmagick.org/

LICENSE
-------

* BSD3
