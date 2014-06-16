HTMLDOC := $(BUILD)/htmldoc

htmldoc: $(HTMLDOC)/htmldoc.tgz

htmldoc/clean:
	rm -rf $(HTMLDOC)

$(TOOLS)/htmldoc/node_modules: $(TOOLS)/htmldoc/package.json
	cd $(TOOLS)/htmldoc && npm install && touch $(TOOLS)/htmldoc/node_modules

$(HTMLDOC)/index.html: $(LOCAL_COMPONENTS)/lib/htmldoc/component-build/component-is-build $(TOOLS)/htmldoc/node_modules $(TOOLS)/htmldoc/htmldoc.jade
	@rm -rf $(HTMLDOC)
	@mkdir -p "$(HTMLDOC)"
	tar -c --exclude component-is-build --directory "$(<D)" . | tar -x --directory "$(HTMLDOC)"
	$(TOOLS)/htmldoc/node_modules/.bin/coffee $(TOOLS)/htmldoc/htmldoc.coffee
	@touch $(HTMLDOC)/index.html

.SECONDARY: $(HTMLDOC)/%

$(HTMLDOC)/htmldoc.tgz: $(HTMLDOC)/index.html
	@rm -f $(HTMLDOC)/htmldoc.tgz
	cd $(HTMLDOC) && tar -czf htmldoc.tgz --exclude htmldoc.tgz *

