MD_FILES := $(wildcard *.md)
HTML_FILES := $(patsubst %.md, build/%.html, $(MD_FILES))

build/%.html: %.md
	@mkdir -p build
	@markdown $< > $@

html_doc: $(HTML_FILES)

clean:
	rm -rf build

.PHONY:
	clean