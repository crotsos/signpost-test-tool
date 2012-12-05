signpost-test-tool
==================


Introduction
============

Signpost measurement tool is an ocaml tool that is developed in order to allow a large 
scale experiment to test the ability to use dnssec server across the internet. 

Requirements
=============

- linux:

    a small numbers of tools is required in order to build the test tool. In ubuntu system you need to run the following command:
    > sudo apt-get install autoconf automake libtool m4 autotools-dev libssl-dev curl make
    
- MacOSX:

    in order to build and run the signpost-test-tool you need to install the Xcode system, which is distributed freely 
    by the AppStore. Also you need to install brew install system and install the ocaml base system. In order to install 
    brew you need to execute the following steps from the command line:
    > ruby -e "$(curl -fsSkL raw.github.com/mxcl/homebrew/go)"
    
    > brew install ocaml


Usage
=====

> curl https://raw.github.com/crotsos/signpost-test-tool/master/signpost_test_install.sh >  signpost_test_install.sh

> chmod a+x signpost_test_install.sh

> ./signpost_test_install.sh

At some point the install script will require root access in order to setup the iodine device. The tool will run a number
of dns test and upload only a log file with the result of the dns queries. 