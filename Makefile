.PHONY: all
all:
	zola build -o docs

.PHONY: serve
serve:
	zola serve

.PHONY: clean
clean:
	rm -rf docs/
