#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

die() { echo "$*" >&2; exit 1; }

TEMP="$(mktemp -d -t python.XXXXXX)" || die "failed to make tmpdir"
cleanup() { [[ -n "${TEMP:-}" ]] && rm -rf "${TEMP}"; }
trap cleanup EXIT

INSTALL_ROOT="${INSTALL_ROOT:-$HOME/Python}"
CPY=$INSTALL_ROOT/CPython
PYPY=$INSTALL_ROOT/PyPy

READLINE_URL="ftp://ftp.cwru.edu/pub/bash/readline-6.2.tar.gz"
READLINE_FILENAME="$(basename $READLINE_URL)"
READLINE_VERNAME="${READLINE_FILENAME%%.tar.gz}"

READLINE_PREFIX="$INSTALL_ROOT/$READLINE_VERNAME"

SANDBOX="$TEMP/sandbox"

sane_curl() {
  wget --no-check-certificate "$@"
}

mkdir -p "$SANDBOX" "$INSTALL_ROOT" "$READLINE_PREFIX"

PYTHON_2_6=2.6.9
PYTHON_2_7=2.7.9
PYTHON_3_3=3.3.6
PYTHON_3_4=3.4.2
PY_PY=2.5.0
SETUPTOOLS=12.0.5
PIP=6.0.8

case "$(uname -s)" in
Linux)
  READLINE_FLAGS='--enable-shared'
;;
Darwin)
  READLINE_FLAGS='--disable-shared --enable-static'
;;
esac

pushd $SANDBOX
  sane_curl "$READLINE_URL"
  tar xzf "$READLINE_FILENAME"
  pushd readline-6.2
    ./configure $READLINE_FLAGS --prefix="$READLINE_PREFIX"
    make -j3 && make install
  popd
  rm -rf readline-6.2.tar.gz readline-6.2

  # install all major cpython interpreter versions
  for version in $PYTHON_2_6 $PYTHON_2_7 $PYTHON_3_3 $PYTHON_3_4; do
    sane_curl http://python.org/ftp/python/$version/Python-$version.tgz
    tar xzf Python-$version.tgz
    pushd Python-$version
      LDFLAGS=-L"$READLINE_PREFIX/lib" CFLAGS=-I"$READLINE_PREFIX/include" \
        ./configure --with-readline --prefix=$INSTALL_ROOT/CPython-$version && make -j5 && make install
    popd
    rm -f Python-$version.tgz
  done

  # install pypy
  for pypy_version in $PY_PY-osx64; do
    pushd $INSTALL_ROOT
      sane_curl https://bitbucket.org/pypy/pypy/downloads/pypy-$pypy_version.tar.bz2
      bzip2 -cd pypy-$pypy_version.tar.bz2 | tar -xf -
      rm -f pypy-$pypy_version.tar.bz2
      mv pypy-$pypy_version PyPy-$PY_PY
    popd
  done

  sane_curl https://pypi.python.org/packages/source/s/setuptools/setuptools-$SETUPTOOLS.tar.gz
  sane_curl http://pypi.python.org/packages/source/p/pip/pip-$PIP.tar.gz

  for interpreter in $CPY-$PYTHON_2_6/bin/python2.6 \
                     $CPY-$PYTHON_2_7/bin/python2.7 \
                     $CPY-$PYTHON_3_3/bin/python3.3 \
                     $CPY-$PYTHON_3_4/bin/python3.4 \
                     $PYPY-$PY_PY/bin/pypy; do
    # install distribute && pip
    for base in setuptools-$SETUPTOOLS pip-$PIP; do
      tar xzf $base.tar.gz
      pushd $base
        $interpreter setup.py install
      popd
      rm -rf $base
    done
  done

  rm -f setuptools-$SETUPTOOLS.tar.gz pip-$PIP.tar.gz
popd

METAPATH='$PATH'
READLINE_RE="/$READLINE_VERNAME/"
for path in $(ls $INSTALL_ROOT | sort -r); do

  [[ "$path" =~ $READLINE_RE ]] && continue

  METAPATH=$INSTALL_ROOT/$path/bin:$METAPATH
done

echo Add the following line to the end of your .bashrc:
echo PATH=$METAPATH

rm -rf $SANDBOX
