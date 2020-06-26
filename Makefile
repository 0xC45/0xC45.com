.PHONY: all
all:
	PROJECT_ROOT="$$(git rev-parse --show-toplevel)" && \
	docker run \
	  --rm \
	  -it \
	  -u $$(id -u $${USER}):$$(id -g $${USER}) \
	  -v "$${PROJECT_ROOT}:/site" \
	  zola:v0.11.0 \
	  bash -c 'cd /site && zola build -o docs'

.PHONY: serve
serve:
	PROJECT_ROOT="$$(git rev-parse --show-toplevel)" && \
	docker run \
	  --rm \
	  -it \
	  -u $$(id -u $${USER}):$$(id -g $${USER}) \
	  -v "$${PROJECT_ROOT}:/site" \
	  -p 127.0.0.1:1111:1111 \
	  zola:v0.11.0 \
	  bash -c 'cd /site && zola serve -i 0.0.0.0'

.PHONY: clean
clean:
	rm -rf docs/
