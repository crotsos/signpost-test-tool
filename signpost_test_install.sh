#!/usr/bin/env bash 

set -x 

cd /tmp/
mkdir signpost-test/

dir=`pwd`

if [ ! $(which opam) ]; then

  echo "fetch and install opam... "
  git clone git://github.com/OCamlPro/opam.git
  cd opam
  ./configure --prefix=$dir
  make all install 
  cd ..
  PATH=$dir/bin/:$PATH
fi

echo "init the repo...."
opam --root opam_repo init
eval `opam --root opam_repo config -env`

echo "install new compiler "
opam --root opam_repo switch 3.12.1
eval `opam --root opam_repo config -env`

echo "adding opam signpost repo and install required packages..."
opam --root opam_repo remote -kind git -add signpostd \
  git://github.com/crotsos/opam-repo-dev.git
opam --root opam_repo install ssl lwt cmdliner
opam --root opam_repo install dns.1.0.1

echo "FInally, fetch and compile test tool...."
git clone git://github.com/crotsos/signpost-test-tool.git
make -C signpost-test-tool

echo "Running test..."
cd signpost-test-tool/ 
sudo ./test.native
cd ../../
rm -r signpost-test/

