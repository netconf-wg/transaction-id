LIBDIR := lib
include $(LIBDIR)/main.mk

$(LIBDIR)/main.mk:
ifneq (,$(shell grep "path *= *$(LIBDIR)" .gitmodules 2>/dev/null))
	git submodule sync
	git submodule update $(CLONE_ARGS) --init
else
	git clone -q --depth 10 $(CLONE_ARGS) \
	    -b main https://github.com/martinthomson/i-d-template $(LIBDIR)
endif

TARGETS = draft-ietf-netconf-transaction-id.html draft-ietf-netconf-transaction-id.txt
YANGS = ietf-netconf-txid.yang ietf-netconf-txid-yang-push.yang ietf-netconf-txid-nmda-compare.yang 
EXAMPLES_XML = ex-01-request.xml ex-01-response-human-readable.xml ex-01-response.xml ex-02-request.xml ex-03-request.xml ex-03-response.xml ex-04-request.xml ex-04-response.xml ex-06-request.xml ex-06-response-changed.xml ex-06-response-no-change.xml ex-07-request.xml ex-07-response.xml ex-08-request.xml ex-08-response.xml ex-09-response-no-change.xml ex-09-response-oob-change.xml ex-10-request.xml ex-10-response.xml ex-11-response-accepted.xml ex-11-response-rejected.xml ex-12-request.xml ex-13-response.xml ex-14-request.xml ex-14-response.xml ex-16-request.xml ex-16-response.xml ex-17-request.xml ex-20-request.xml ex-20-response.xml
EXAMPLES_JSON = ex-20-response-body.json
EXAMPLES = $(EXAMPLES_XML) $(EXAMPLES_JSON) ex-20-response-header.http
SOURCES = draft-ietf-netconf-transaction-id.md $(patsubst %,yang/%, $(YANGS)) $(patsubst %,examples/%, $(EXAMPLES))
$(TARGETS): $(SOURCES)

.PHONY: validate
validate: validate-yangs validate-examples

validate-yangs:
	$(YANGER)