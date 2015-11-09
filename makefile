uname_s         := $(shell sh -c 'uname -s 2>/dev/null || echo undefined')

distroot        ?= $(CURDIR)/priv
buildroot       ?= _build/dev

bin_elixir   	?= elixir
bin_gmconfig 	?= GraphicsMagick-config
bin_install     ?= install
ifeq ($(uname_s),Darwin)
bin_libtool     ?= glibtool
else
bin_libtool     ?= libtool
endif

gm_libs      	:= $(shell $(bin_gmconfig) --libs)
gm_cflags    	:= $(shell $(bin_gmconfig) --cflags --cppflags)
gm_ldflags   	:= $(shell $(bin_gmconfig) --ldflags)
erlang_flags 	:= $(shell $(bin_elixir) -e 'IO.puts (Path.join [:code.root_dir, ["erts-", :erlang.system_info(:version)], "include"])')

exmagick_rpath  := $(shell $(CURDIR)/bin/rpath.sh $(gm_ldflags))
exmagick_cflags  = -pedantic -ansi -I$(erlang_flags) $(gm_cflags)
exmagick_ldflags = $(gm_ldflags) -rpath $(exmagick_rpath) -L/usr/local/lib
exmagick_ld_libs = $(gm_libs)

srcfiles = $(wildcard lib/c/*.c)
objfiles = $(addprefix $(buildroot)/, $(addsuffix .lo, $(basename $(srcfiles))))

libname  = libexmagick
libfile  = $(buildroot)/$(libname).la

build: $(libfile)
compile: build

clean:
	$(bin_libtool) --mode=clean rm -f $(objfiles)
	$(bin_libtool) --mode=clean rm -f $(libfile)

install: $(distroot)/lib/$(libname).la

$(distroot)/lib/$(libname).la: $(libfile)
	test -d $(@D) || mkdir -p $(@D)
	$(bin_libtool) --mode=install $(bin_install) $(<) $(@)
	if [ ! -e $(@D)/$(libname).so ]; \
	then \
	  if [ -e $(@D)/$(libname).dylib ]; \
	  then ln -s $(libname).dylib $(@D)/$(libname).so; fi;\
	fi

$(buildroot)/%.lo: %.c
	test -d $(@D) || mkdir -p $(@D)
	$(bin_libtool) --tag=CC --mode=compile $(CC) $(CFLAGS) $(exmagick_cflags) -c $(<) -o $(@)

$(libfile): $(objfiles)
	test -d $(@D) || mkdir -p $(@D)
	$(bin_libtool) --tag=CC --mode=link $(bin_install) $(CC) $(LD_FLAGS) $(exmagick_ldflags) $(<) -o $(@) $(LD_LIBS) $(exmagick_ld_libs)
