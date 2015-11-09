#!/bin/sh

while getopts :L: opt
do
  case $opt in
    L) rpath="$OPTARG"
       ;;
    ?) ;;
  esac
done

echo "${rpath:-/lib}"
