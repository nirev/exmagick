#!/bin/sh

set -e

exec 1>/dev/null
exec 2>/dev/null

make_test () {
  echo '
  #include "erl_nif.h"
  int main () {
    int x = ERL_NIF_DIRTY_JOB_CPU_BOUND;
    return 0;
  }
  '
}

tempfile=$(mktemp "XXXXXXXX.c") && {
  trap 'rm -f "$tempfile"' EXIT

  make_test >"$tempfile"
  $CC $CFLAGS -c "$tempfile" -o/dev/null
}
