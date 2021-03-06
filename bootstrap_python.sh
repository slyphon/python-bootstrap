#!/bin/bash
set -eu
set -o pipefail

INSTALL_ROOT="${INSTALL_ROOT:-$HOME/Python}"
CPY=$INSTALL_ROOT/CPython
PYPY=$INSTALL_ROOT/PyPy
READLINE_PREFIX="${INSTALL_ROOT}/readline-6.2"

die() { echo "fatal: $@" >&2; exit 1; }

SANDBOX="$(mktemp -d /tmp/python.XXXXXX)" || die "failed to create sandbox"

cleanup() { [[ -n "${SANDBOX:-}" ]] && rm -rf "${SANDBOX}"; }
trap cleanup EXIT

CURL='wget --no-check-certificate'

mkdir -p "$INSTALL_ROOT"

PYTHON_2_6=2.6.9
PYTHON_2_7=2.7.10
PYTHON_3_3=3.3.6
PYTHON_3_4=3.4.3
PY_PY=2.6.0
SETUPTOOLS=18.1
PIP=7.1.0

pushd $SANDBOX
  wget http://mirrors.kernel.org/gnu/readline/readline-6.2.tar.gz
  tar xzf readline-6.2.tar.gz
  pushd readline-6.2
    ./configure --disable-shared --enable-static --prefix="$READLINE_PREFIX" && \
    make -j3 && make install
  popd
  rm -rf readline-6.2.tar.gz readline-6.2

  # install all major cpython interpreter versions
  for version in $PYTHON_2_6 $PYTHON_2_7 $PYTHON_3_3 $PYTHON_3_4; do
    $CURL http://python.org/ftp/python/$version/Python-$version.tgz
    tar xzf Python-$version.tgz
    pushd Python-$version
      LDFLAGS=-L"$READLINE_PREFIX/lib" CFLAGS=-I"$READLINE_PREFIX/include" \
        ./configure --prefix="$INSTALL_ROOT/CPython-$version" && make -j5 && make install
    popd
    rm -f Python-$version.tgz
  done

  # install pypy
  for pypy_version in $PY_PY-osx64; do
    pushd $INSTALL_ROOT
      $CURL https://bitbucket.org/pypy/pypy/downloads/pypy-$pypy_version.tar.bz2
      bzip2 -cd pypy-$pypy_version.tar.bz2 | tar -xf -
      rm -f pypy-$pypy_version.tar.bz2
      mv pypy-$pypy_version PyPy-$PY_PY
    popd
  done

  $CURL https://pypi.python.org/packages/source/s/setuptools/setuptools-$SETUPTOOLS.tar.gz
  $CURL http://pypi.python.org/packages/source/p/pip/pip-$PIP.tar.gz

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
for path in $(ls $INSTALL_ROOT | sort -r); do
  METAPATH=$INSTALL_ROOT/$path/bin:$METAPATH
done

echo Add the following line to the end of your .bashrc:
echo PATH=$METAPATH

