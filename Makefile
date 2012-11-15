.PHONY: all clean distclean setup build doc install test
all: build

J ?= 2
NAME=signpost-test

setup.data: setup.bin
	./setup.bin -configure 
distclean: setup.data setup.bin
	./setup.bin -distclean $(OFLAGS)
	$(RM) setup.bin

setup: setup.data

build: setup.data  setup.bin
	./setup.bin -build -j $(J) $(OFLAGS)

clean:
	ocamlbuild -clean
	rm -f setup.data setup.bin

setup.bin: setup.ml
	ocamlopt.opt -o $@ $< || ocamlopt -o $@ $< || ocamlc -o $@ $<
	$(RM) setup.cmx setup.cmi setup.o setup.cmo

setup.ml: _oasis
	oasis setup
