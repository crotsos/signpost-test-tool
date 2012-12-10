#!/usr/bin/env bash 

set -e 

cd /tmp/
mkdir signpost-test/
cd signpost-test/

dir=`pwd`

echo "Please provide a description of the location:"
read loc
echo "Please provide the name of the isp you are connecting from:"
read isp
echo "Please provide the type of the device you are running the test:"
read device

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
opam --yes --root opam_repo remote -kind git -add signpostd \
  git://github.com/crotsos/opam-repo-dev.git
opam --yes --root opam_repo install ssl lwt cmdliner
opam --yes --root opam_repo install dns.1.0.1

echo "Finally, fetch and compile test tool...."
git clone git://github.com/crotsos/signpost-test-tool.git
make -C signpost-test-tool

echo "Running test..."
cd signpost-test-tool/ 
sudo ./test.native -d "$device" -i "$isp" -l "$loc"
cd ../../
rm -r /tmp/signpost-test/

