.PHONY: all clean distclean setup build doc install test
all: stateos build

TARGETOS = `/usr/bin/uname`
OS = $(shell uname | tr "a-z" "A-Z")
ARCH = `uname -m`

#LDFLAGS +=  -lflags -cclib -lflags -lz \
#		$(shell sh src/osflags $(TARGETOS) link) \
#		-lflags -cclib -lflags -lcrypto
#CFLAGS += -cflags -ccopt -cflags -D$(OS) -cflags -ccopt -cflags -pedantic $(shell sh src/osflags $(TARGETOS) cflags)

J ?= 2
NAME=signpost-test

stateos:
	@echo OS is $(OS), arch is $(ARCH)

setup.data: setup.bin
	./setup.bin -configure 
distclean: setup.data setup.bin
	./setup.bin -distclean $(OFLAGS)
	$(RM) setup.bin

setup: setup.data

src/base64u.c: src/base64.c
	@echo Making $@
	@echo '/* No use in editing, produced by Makefile! */' > $@
	@sed -e 's/\([Bb][Aa][Ss][Ee]64\)/\1u/g ; s/0123456789+/0123456789_/' < src/base64.c >> $@
src/base64u.h: src/base64.h
	@echo Making $@
	@echo '/* No use in editing, produced by Makefile! */' > $@
	@sed -e 's/\([Bb][Aa][Ss][Ee]64\)/\1u/g ; s/0123456789+/0123456789_/' < src/base64.h >> $@

build: setup.data  setup.bin src/base64u.c src/base64u.h
	./setup.bin -build -j $(J) $(CFLAGS) $(LDFLAGS) $(OFLAGS)

clean:
	ocamlbuild -clean
	rm -f setup.data setup.bin

setup.bin: setup.ml
	ocamlopt.opt -o $@ $< || ocamlopt -o $@ $< || ocamlc -o $@ $<
	$(RM) setup.cmx setup.cmi setup.o setup.cmo base64u.h base64u.c

setup.ml: _oasis
	oasis setup
