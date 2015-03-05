HTMLDOC := $(BUILD)/htmldoc
HTMLDOC_SRC := $(dir $(lastword $(MAKEFILE_LIST)))

htmldoc: $(HTMLDOC)/htmldoc.tgz

$(HTMLDOC)/index.html: $(LOCAL_COMPONENTS)/lib/htmldoc/component-build/component-is-build $(HTMLDOC_SRC)/htmldoc.jade
	@rm -rf $(HTMLDOC)
	@mkdir -p "$(HTMLDOC)"
	tar -c --exclude component-is-build --directory "$(<D)" . | tar -x --directory "$(HTMLDOC)"
	$(HTMLDOC_SRC)/node_modules/.bin/coffee $(HTMLDOC_SRC)/htmldoc.coffee
	@touch $(HTMLDOC)/index.html

.SECONDARY: $(HTMLDOC)/%

$(HTMLDOC)/htmldoc.tgz: $(HTMLDOC)/index.html
	@rm -f $(HTMLDOC)/htmldoc.tgz
	cd $(HTMLDOC) && tar -czf htmldoc.tgz --exclude htmldoc.tgz *

.PHONY: htmldoc htmldoc/clean htmldoc/realclean

install: htmldoc
clean: htmldoc/clean
