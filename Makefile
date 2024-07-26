GOPATH:=$(shell go env GOPATH)

GO_SOURCES := $(wildcard *.go)
GO_SOURCES += $(shell find . -type f -name "*.go")

GOFMT ?= gofmt -s

ifeq ($(filter $(TAGS_SPLIT),bindata),bindata)
	GO_SOURCES += $(BINDATA_DEST)
endif

GO_SOURCES_OWN := $(filter-out vendor/%, $(GO_SOURCES))

PROTO_SRC_DIR := ${PWD}/gitbeam.baselib/protos
PROTO_DST_DIR := ${PWD}/api/pb/


.PHONY: proto
proto:
	go get github.com/golang/protobuf/protoc-gen-go
	go install github.com/golang/protobuf/protoc-gen-go
	mkdir -p ${PROTO_DST_DIR}/repos && protoc -I=${PROTO_SRC_DIR} --go_out=plugins=grpc:${PROTO_DST_DIR}/repos ${PROTO_SRC_DIR}/repos/repos.proto
	mkdir -p ${PROTO_DST_DIR}/commits && protoc -I=${PROTO_SRC_DIR} --go_out=plugins=grpc:${PROTO_DST_DIR}/commits ${PROTO_SRC_DIR}/commits/commits.proto
	make alignment


.PHONY: test
test: gen-mocks
	go test -v ./... -cover

gen-mocks:
	go get github.com/golang/mock/gomock
	go generate ./...

tools:
	go get golang.org/x/tools/cmd/goimports
	go get github.com/kisielk/errcheck
	go get golang.org/x/lint/golint
	go get github.com/axw/gocov/gocov
	go get github.com/matm/gocov-html
	go get github.com/tools/godep
	go get github.com/mitchellh/gox

lint:
	@hash golangci-lint > /dev/null 2>&1; if [ $$? -ne 0 ]; then \
		export BINARY="golangci-lint"; \
		curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s -- -b $(GOPATH)/bin v1.51.2; \
	fi
	golangci-lint run --timeout 5m

vet:
	go vet -v ./...

fmt:
	gofmt -w .

fmt-check:
	@diff=$$($(GOFMT) -d $(GO_SOURCES_OWN)); \
	if [ -n "$$diff" ]; then \
		echo "Please run 'make fmt' and commit the result:"; \
		echo "$${diff}"; \
		exit 1; \
	fi;

errors:
	errcheck -ignoretests -blank ./...

coverage:
	gocov test ./... > $(CURDIR)/coverage.out 2>/dev/null
	gocov report $(CURDIR)/coverage.out
	if test -z "$$CI"; then \
	  gocov-html $(CURDIR)/coverage.out > $(CURDIR)/coverage.html; \
	  if which open &>/dev/null; then \
	    open $(CURDIR)/coverage.html; \
	  fi; \
	fi


alignment:
	go run golang.org/x/tools/go/analysis/passes/fieldalignment/cmd/fieldalignment -fix ./models  > /dev/null 2>&1 || :
