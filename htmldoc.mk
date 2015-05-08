HTMLDOC := $(BUILD)/htmldoc
HTMLDOC_SRC := $(dir $(lastword $(MAKEFILE_LIST)))
COFFEE_CLI=$(shell node -e 'path = require("path"); p = require.resolve("coffee-script"); while (p && path.basename(path.dirname(p)) != "node_modules") p = path.dirname(p); p = path.join(p, "bin", "coffee"); console.log(p)')
$(info $(NPM_BIN))
htmldoc: $(HTMLDOC)/htmldoc.tgz

$(HTMLDOC)/index.html: $(LOCAL_COMPONENTS)/lib/htmldoc/component-build/component-is-build $(HTMLDOC_SRC)/htmldoc.jade
	@rm -rf $(HTMLDOC)
	@mkdir -p "$(HTMLDOC)"
	tar -c --exclude component-is-build --directory "$(<D)" . | tar -x --directory "$(HTMLDOC)"
	$(COFFEE_CLI) $(HTMLDOC_SRC)htmldoc.coffee
	@touch $(HTMLDOC)/index.html

.SECONDARY: $(HTMLDOC)/%

$(HTMLDOC)/htmldoc.tgz: $(HTMLDOC)/index.html
	@rm -f $(HTMLDOC)/htmldoc.tgz
	cd $(HTMLDOC) && tar -czf htmldoc.tgz --exclude htmldoc.tgz *

.PHONY: htmldoc htmldoc/clean htmldoc/realclean

install: htmldoc
clean: htmldoc/clean
