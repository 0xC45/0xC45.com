+++
title = "My Zola Workflow"
+++

## Overview
To build this website, I use the [Zola static site engine](https://www.getzola.org/). So far, it has worked great. In this blog post, I will discuss my workflow improvements for using Zola, developing my blog posts, and publishing this website. As a quick intro, however, I will give a brief summary of the main features of Zola and why I chose to use it.

### What is Zola?
Zola advertises itself as a static site engine. It "compiles" Markdown content files, HTML templates (based on the [Tera template engine](https://tera.netlify.app/)), and [Sass](https://sass-lang.com/) styling into static HTML and CSS pages. This way, a Zola website does not require any server-side code to "render" the website pages.

In addition, Zola has several convenience features that one would want for a blog or website, such as built-in [syntax highlighting](https://www.getzola.org/documentation/content/syntax-highlighting/), simplified [pagination](https://www.getzola.org/documentation/templates/pagination/), and auto-generation of [atom/rss feeds](https://www.getzola.org/documentation/templates/feeds/).

So, Zola is an all-in-one tool for generating static websites. As a blog author, I can mainly focus on writing my blog post content (in Markdown). I don't have to worry too much about HTML syntax, CSS styling, linking, pagination, or my Atom feed (after the initial setup and creation of my site theme). When I'm done writing a blog post, I "generate" the static site with Zola. All of the repetitive and error-prone work is handled for me and the actual static website pages are produced.

### Why use Zola?
There are many competing static site generators out there. Zola is but one of many. Currently, Hugo and Jekyll are probably the two most popular static site generators. However, for this website, I chose to use Zola for a few reasons:

* It's simple. It doesn't have a ridiculous number of features that will confuse me and distract me from actually writing blog posts.
* It's capable. It has all the feature that I need.
* It's a relatively new project. Why not give it a try?


## My Zola Workflow
Rather than repeat stuff you can find in the Zola documentation, in this blog post I will cover three of my personal "workflow hacks" for working with Zola. Hopefully at least a couple of these patterns are useful to you.

### Git pre-push Hook
Because this blog is hosted on Github pages, `git push` is equivalent to publishing the site. Early on, I made the mistake of writing an entire blog post, but forgetting to "generate" the static site. So, I made a commit, pushed, and nothing happened.

To prevent myself from making this mistake again, I added a "pre-push" hook to my git repo. Now, git will refuse to push if the generated static site is out of date.

Here is my simple "pre-push" git hook:
```bash
#!/usr/bin/env bash

project_root="$( git rev-parse --show-toplevel )"
pushd "${project_root}" &> /dev/null || exit 1
make &> /dev/null
num_diff_files="$( git diff --name-only | wc -l )"
num_untracked_files="$( git ls-files --others --exclude-standard | wc -l )"
if [ "${num_diff_files}" != "0" ] || [ "${num_untracked_files}" != "0" ] ; then
  echo "diff detected after running \`make\`, not pushing"
  exit 1
fi
popd &> /dev/null || exit 1
```

In summary, this git hook builds the site (with Zola) and then checks if any git diff is detected. If there is a git diff (or new, un-tracked file), the hook will prevent the `git push` from running.

As you might notice, this script depends on `make`. To build the website, I have a Makefile target (which will be discussed soon).

### Docker Image
Next, rather than install the `zola` binary on my base system, I decided to create a docker image that contains Zola. So, I now have a portable means to generate the site. In the future, I could potentially add some sort of continuous deployment automation to regenerate the site on every git push using this docker image. Additionally, the docker image locks Zola at a specific version (which I can be conscientious about upgrading).

Here is my Zola docker image: [https://github.com/0xC45/zola-docker](https://github.com/0xC45/zola-docker).

### Makefile
Lastly, I use a Makefile to build the site. Because I use a docker image to run Zola, some of the commands are quite complicated. Particularly, it was somewhat difficult to set up UID/GID mapping and port binding. Using a Makefile documents the commands in code and saves me from having to remember them. Here is my Makefile:

```Makefile
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
```

There are three main targets: `all`, `serve`, and `clean`.
* `all`: This target generates the static site.
* `serve`: This target runs a "development" server on my local machine, allowing me to preview changes.
* `clean`: This target deletes the directory containing the generated static site.


## Conclusion
So, there you have it. These are my custom workflow improvements for using the Zola static site engine. So far, Zola has been a fantastic utility for generating my blog site. Of course, it does not have all the features of other popular static site generators, but it's perfect for my use case. It's simple, easy to use, fast, and capable. I definitely recommend checking it out.