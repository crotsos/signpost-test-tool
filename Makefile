.PHONY: all clean distclean setup build doc install test iodine
all: stateos build iodine

TARGETOS = `/usr/bin/uname`
OS = $(shell uname | tr "a-z" "A-Z")
ARCH = `uname -m`

#LDFLAGS +=  -lflags -cclib -lflags -lz \
#		$(shell sh src/osflags $(TARGETOS) link) \
#		-lflags -cclib -lflags -lcrypto
#CFLAGS += -cflags -ccopt -cflags -D$(OS) -cflags -ccopt -cflags -pedantic $(shell sh src/osflags $(TARGETOS) cflags)

J ?= 2
NAME=signpost-test

iodine:
	$(MAKE) -C iodine

stateos:
	@echo OS is $(OS), arch is $(ARCH)

setup.data: setup.bin
	./setup.bin -configure 
distclean: setup.data setup.bin
	./setup.bin -distclean $(OFLAGS)
	$(RM) setup.bin

setup: setup.data

build: setup.data  setup.bin 
	./setup.bin -build -j $(J) $(CFLAGS) $(LDFLAGS) $(OFLAGS)

clean:
	ocamlbuild -clean
	rm -f setup.data setup.bin

setup.bin: setup.ml
	ocamlopt.opt -o $@ $< || ocamlopt -o $@ $< || ocamlc -o $@ $<
	$(RM) setup.cmx setup.cmi setup.o setup.cmo 

setup.ml: _oasis
	oasis setup
