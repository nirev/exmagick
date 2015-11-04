ExMagick
========

USAGE
-----

```elixir
defp deps do
  [{:exmagick, git: "https://github.com/xerpa/exmagick.git"}]
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

LINKS
-----

* http://www.graphicsmagick.org/

LICENSE
-------

* BSD3
