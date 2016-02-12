TAG = $(shell git  describe --tags --abbrev=0)
UNAME = $(shell uname)

deps:
	curl -L https://github.com/progrium/dockerhub-tag/releases/download/v0.2.0/dockerhub-tag_0.2.0_$(UNAME)_x86_64.tgz | tar -xzC /usr/local/bin
dockerhub-tag:
	dockerhub-tag set sequenceiq/docker-consul-watch-plugn $(TAG) $(TAG) /