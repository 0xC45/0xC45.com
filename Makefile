.PHONY: all
all:
	zola build -o docs

serve:
	zola serve

clean:
	rm -rf docs/