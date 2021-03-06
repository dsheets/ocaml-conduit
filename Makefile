.PHONY: all install clean doc github test cdtest cdtest_tls

EXT_OBJ:=$(shell ocamlfind ocamlc -config | awk '/^ext_obj:/ {print $$2}')
EXT_LIB:=$(shell ocamlfind ocamlc -config | awk '/^ext_lib:/ {print $$2}')

OCAMLBUILD = ocamlbuild -use-ocamlfind -classic-display \
	-cflags "-w A-4-33-40-41-42-43-34-44" \
	-plugin-tag "package(ppx_driver.ocamlbuild)"

PREFIX ?= /usr/local/bin
OS_TYPE:=$(shell ocamlfind ocamlc -config | awk '/^os_type:/ {print $$2}')
ifeq ($(OS_TYPE),$(filter $(OS_TYPE),Win32 Cygwin))
EXT_EXE=.exe
else
EXT_EXE=
endif


B=_build/lib
FILES = $(wildcard $B/*.cmi $B/*.cmt $B/*.cmti $B/*.cmx $B/*.cmxa $B/*.cma $B/*.cmxs $B/*$(EXT_LIB) $B/*$(EXT_OBJ) $B/*.cmo)
MORE_FILES = $(wildcard lib/intro.html $B/*.mli)

all:
	$(OCAMLBUILD) conduit.otarget

install:
	rm -rf _install
	mkdir -p _install
ifneq ("$(wildcard _build/lib/conduit_xenstore.cmo)","")
	echo '"scripts/xenstore-conduit-init" {"xenstore-conduit-init"}' > _install/bin
endif
	$(foreach f,$(FILES), echo "$(f)" >> _install/lib;)
	ocamlfind remove conduit || true
	ocamlfind install conduit META $(FILES) $(MORE_FILES)

clean:
	$(OCAMLBUILD) -clean
	rm -rf _install lib/conduit_config.mlh META _tags

doc:
	$(OCAMLBUILD) lib/conduit.docdir/index.html

github: doc
	git checkout gh-pages
	git merge master --no-edit
	$(MAKE)
	rm -f *.html
	cp _build/lib/conduit-all.docdir/* .
	git add *.html
	cp nice-style.css style.css
	git add style.css
	git commit -m 'sync ocamldoc' *.html *.css
	git push
	git checkout master

VERSION = $(shell cat VERSION)
NAME    = conduit
ARCHIVE = https://github.com/mirage/ocaml-$(NAME)/archive/v$(VERSION).tar.gz

release:
	git tag -a v$(VERSION) -m "Version $(VERSION)."
	git push upstream v$(VERSION)
	$(MAKE) pr

pr:
	opam publish prepare $(NAME).$(VERSION) $(ARCHIVE)
	OPAMYES=1 opam publish submit $(NAME).$(VERSION) && rm -rf $(NAME).$(VERSION)

# have(openssl) -> generate test certificates
# have(lwt.unix tls.lwt ipaddr.unix lwt.ssl openssl) -> build(cdtest) and run(cdtest)
# have(lwt.unix tls.lwt ipaddr.unix openssl) -> build(cdtest_tls) and run(cdtest_tlsOB)
test:
	$(OCAMLBUILD) tests.otarget
	! openssl version || tests/unix/gen.sh
	! ocamlfind query lwt.unix tls.lwt ipaddr.unix lwt.ssl || ! openssl version || ($(MAKE) cdtest && ./cdtest.native)
	! ocamlfind query lwt.unix tls.lwt ipaddr.unix || ! openssl version || ($(MAKE) cdtest_tls && ./cdtest_tls.native)
	! ocamlfind query lwt.unix tls.lwt ipaddr.unix || ! openssl version || (CONDUIT_TLS=native ./cdtest_tls.native)
