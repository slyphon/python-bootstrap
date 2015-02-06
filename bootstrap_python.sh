INSTALL_ROOT=$HOME/Python
CPY=$INSTALL_ROOT/CPython
PYPY=$INSTALL_ROOT/PyPy

SANDBOX=$(mktemp -d /tmp/python.XXXXXX)

CURL='wget --no-check-certificate'

mkdir -p $INSTALL_ROOT

pushd $SANDBOX
  wget ftp://ftp.cwru.edu/pub/bash/readline-6.2.tar.gz
  tar xzf readline-6.2.tar.gz
  pushd readline-6.2
    ./configure --disable-shared --enable-static --prefix=$SANDBOX/readline
    make -j3 && make install
  popd
  rm -rf readline-6.2.tar.gz readline-6.2

  # install all major cpython interpreter versions
  for version in 2.6.9 2.7.8 3.3.5 3.4.1; do
    $CURL http://python.org/ftp/python/$version/Python-$version.tgz
    tar xzf Python-$version.tgz
    pushd Python-$version
      LDFLAGS=-L$SANDBOX/readline/lib CFLAGS=-I$SANDBOX/readline/include \
        ./configure --prefix=$INSTALL_ROOT/CPython-$version && make -j5 && make install
    popd
    rm -f Python-$version.tgz
  done
  
  # install pypy
  for pypy_version in 2.2.1-osx64; do
    pushd $INSTALL_ROOT
      $CURL https://bitbucket.org/pypy/pypy/downloads/pypy-$pypy_version.tar.bz2
      bzip2 -cd pypy-$pypy_version.tar.bz2 | tar -xf -
      rm -f pypy-$pypy_version.tar.bz2
      mv pypy-$pypy_version PyPy-2.2.1
    popd
  done

  $CURL https://pypi.python.org/packages/source/s/setuptools/setuptools-3.4.4.tar.gz
  $CURL http://pypi.python.org/packages/source/p/pip/pip-1.5.4.tar.gz
  
  for interpreter in $CPY-2.6.9/bin/python2.6 \
                     $CPY-2.7.8/bin/python2.7 \
                     $CPY-3.3.5/bin/python3.3 \
                     $CPY-3.4.1/bin/python3.4 \
                     $PYPY-2.2.1/bin/pypy; do
    # install distribute && pip
    for base in setuptools-3.4.4 pip-1.5.4; do
      tar xzf $base.tar.gz
      pushd $base
        $interpreter setup.py install
      popd
      rm -rf $base
    done
  done
  
  rm -f setuptools-3.4.4.tar.gz pip-1.5.4.tar.gz
popd

METAPATH='$PATH'
for path in $(ls $INSTALL_ROOT | sort -r); do
  METAPATH=$INSTALL_ROOT/$path/bin:$METAPATH
done

echo Add the following line to the end of your .bashrc:
echo PATH=$METAPATH

rm -rf $SANDBOX