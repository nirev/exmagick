# ExMagick

[![Module Version](https://img.shields.io/hexpm/v/exmagick.svg)](https://hex.pm/packages/exmagick)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/exmagick/)
[![Total Download](https://img.shields.io/hexpm/dt/exmagick.svg)](https://hex.pm/packages/exmagick)
[![License](https://img.shields.io/hexpm/l/exmagick.svg)](https://github.com/Xerpa/exmagick/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/Xerpa/exmagick.svg)](https://github.com/Xerpa/exmagick/commits/master)

ExMagick is a library for manipulating images interfacing with GraphicsMagick.
It's implemented using Erlang NIFs (Native Implemented Functions).

## Installation

The package can be installed by adding `:exmagick` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:exmagick, "~> 1.0.0"}
  ]
end
```

## Dependencies

### GNU/Linux

* `libtool`
* `c compiler`
* `graphicsmagick`

#### Arch Linux ####

```bash
$ pacman -S gcc make libtool graphicsmagick
```

#### Debian ####

```bash
$ apt-get install gcc make libtool-bin libgraphicsmagick1-dev
```

### macOS

```bash
$ brew install libtool
$ brew install graphicsmagick
```

## Testing

If you have all dependencies satisfied then the following should pass:

```bash
$ mix test
```

## Dirty Scheduler

The library has support for using dirty scheduler but it is disabled
by default. To enable it, define an environment variable before
compiling:

```bash
$ env exm_dirty_sched=auto mix compile
```

It will enable dirty scheduler support when the machine provides
support for it.

## See Also

* http://www.graphicsmagick.org/

## Copyright and License

Copyright (c) 2015 Diego Souza

This library licensed under the [BSD 3-Clause "New" or "Revised" License](./LICENSE.md).
