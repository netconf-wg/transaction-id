---
stand_alone: true
ipr: trust200902
title: "Transaction ID Mechanism for NETCONF"
abbrev: "NCTID"
category: std
submissiontype: IETF
area: General
workgroup: NETCONF

docname: draft-ietf-netconf-transaction-id-latest

lang: en
keyword:
  - Internet-Draft

pi:
  - toc
  - sortrefs
  - symrefs

normative:
  RFC2119:
  RFC6241:
  RFC6991:
  RFC7950:
  RFC8040:
  RFC8641:

informative:
  RFC3688:
  RFC6020:
  RFC7232:
  RFC8341:

author:
  - ins: J. Lindblad
    name: Jan Lindblad
    organization: Cisco Systems
    email: jlindbla@cisco.com

--- abstract

NETCONF clients and servers often need to have a synchronized view of
the server's configuration data stores.  The volume of configuration
data in a server may be very large, while data store changes typically
are small when observed at typical client resynchronization intervals.

Rereading the entire data store and analyzing the response for changes
is an inefficient mechanism for synchronization.  This document
specifies an extension to NETCONF that allows clients and servers to
keep synchronized with a much smaller data exchange and without any
need for servers to store information about the clients.

--- middle

# Introduction

When a NETCONF client wishes to initiate a new configuration transaction
with a NETCONF server, a frequently occurring use case is for the
client to find out if the configuration has changed since the client
last communicated with the server.  Such changes could occur for
example if another NETCONF client has made changes, or another system
or operator made changes through other means than NETCONF.

One way of detecting a change for a client would be to
retrieve the entire configuration from the server, then compare
the result with a previously stored copy at the client side.  This
approach is not popular with most NETCONF users, however, since it
would often be very expensive in terms of communications and
computation cost.

Furthermore, even if the configuration is reported to be unchanged,
that will not guarantee that the configuration remains unchanged
when a client sends a subsequent change request, a few moments later.

In order to simplify the task of tracking changes, a NETCONF server
could implement a meta level transaction tag or timestamp for an entire
configuration datastore or YANG subtree, and offer clients a way to
read and compare this tag or timestamp.  If the tag or timestamp is
unchanged, clients can avoid performing expensive operations.  Such
tags and timestamps are referred to as a transaction id (txid) in this
document.

Evidence of a transaction id feature being demanded by clients is that
several server implementors have built proprietary and mutually
incompatible mechanisms for obtaining a transaction id from a NETCONF
server.

RESTCONF, {{RFC8040}},
defines a mechanism for detecting changes in configuration subtrees
based on Entity-Tags (ETags) and Last-Modified txid values.

In conjunction with this, RESTCONF
provides a way to make configuration changes conditional on the server
confiuguration being untouched by others.  This mechanism leverages
{{RFC7232}}
"Hypertext Transfer Protocol (HTTP/1.1): Conditional Requests".

This document defines similar functionality for NETCONF,
{{RFC6241}}, and ties this in
with YANG-Push, {{RFC8641}}.

# Conventions and Definitions

{::boilerplate bcp14}

This document uses the terminology defined in
{{RFC6241}},
{{RFC7950}},
{{RFC8040}}, and
{{RFC8641}}.

In addition, this document defines the following terms:

Versioned node
: A node in the instantiated YANG data tree for which
the server maintains a transaction id (txid) value.

# NETCONF Txid Extension

This document describes a NETCONF extension which modifies the
behavior of get-config, get-data, edit-config, edit-data,
discard-changes, copy-config, delete-config and commit such
that clients are able to conditionally retrieve and update the
configuration in a NETCONF server.

For servers implementing YANG-Push, an extension for conveying txid
updates as part of subscription updates is also defined.

Several low level mechanisms could be defined to fulfill the
requirements for efficient client-server txid synchronization.
This document defines two such mechanisms, the etag txid mechanism
and the last-modified txid mechanism. Additional mechanisms could
be added in future.

## Use Cases

The common use cases for such mecahnisms are briefly discussed here.

Initial configuration retrieval
: When the client initially connects to a server, it may be interested
to acquire a current view of (parts of) the server's configuration.
In order to be able to efficiently detect changes later, it may also
be interested to store meta level txid information for
subtrees of the configuration.

Subsequent configuration retrieval
: When a client needs to reread (parts of) the server's configuration,
it may be interested to leverage the txid meta data it has
stored by requesting the server to prune the response so that it does
not repeat configuration data that the client is already aware of.

Configuration update with txid return
: When a client issues a transaction towards a server, it may be
interested to also learn the new txid meta data the server
has stored for the updated parts of the configuration.

Conditional configuration change
: When a client issues a transaction towards a server, it may specify
txid meta data for the transaction in order to allow the server to
verify that the client is up to date with any changes in the parts of
the configuration that it is concerned with.  If the txid
meta data in the server is different than the client expected, the
server rejects the transaction with a specific error message.

Subscribe to configuration changes with txid return
: When a client subscribes to configuration change updates through
YANG-Push, it may be interested to also learn the the updated txid
meta data for the changed data trees.

## General Txid Principles

All servers implementing a txid mechanism MUST maintain a txid meta
data value for each configuration datastore supported by the server.
Txid mechanism implementations MAY also maintain txid meta data
values for nodes deeper in the YANG data tree.  The nodes for
which the server maintains txids are collectively referred to as the
"versioned nodes".

The server returning txid values for the versioned nodes
MUST ensure the txid values are changed every time there has
been a configuration change at or below the node associated with
the txid value.  This means any update of a config true node will
result in a new txid value for all ancestor versioned nodes, up
to and including the datastore root itself.

This also means a server MUST update the txid value for any
nodes that change as a result of a configuration change, regardless
of source, even if the changed nodes are not explicitly part
of the change payload.  An example of this is dependent data under
YANG {{RFC7950}} when- or
choice-statements.

The server MUST NOT change the txid value of a versioned node
unless the node itself or a child node of that node has
been changed.  The server MUST NOT change any txid values due to
changes in config false data.

## Initial Configuration Retrieval

When a NETCONF server receives a get-config or get-data request
containing requests for txid values, it MUST return txid values for
all versioned nodes below the point requested by the client in
the reply.

The exact encoding varies by mechanism, but all txid mechanisms
would have a special "txid-request" txid value (e.g. "?") which is
guaranteed to never be used as a normal txid value.  Clients MAY use
this special txid value associated with one or more nodes in the
data tree to indicate to the server that they are interested in
txid values below that point of the data tree.

~~~ call-flow
     Client                                            Server
       |                                                 |
       |   ------------------------------------------>   |
       |   get-config                                    |
       |     acls (txid: ?)                              |
       |                                                 |
       |   <------------------------------------------   |
       |   data (txid: 5152)                             |
       |     acls (txid: 5152)                           |
       |       acl A1 (txid: 4711)                       |
       |         aces (txid: 4711)                       |
       |           ace R1 (txid: 4711)                   |
       |             matches ipv4 protocol udp           |
       |       acl A2 (txid: 5152)                       |
       |         aces (txid: 5152)                       |
       |           ace R7 (txid: 4711)                   |
       |             matches ipv4 dscp AF11              |
       |           ace R8 (txid: 5152)                   |
       |             matches udp source-port port 22     |
       |           ace R9 (txid: 5152)                   |
       |             matches tcp source-port port 22     |
       v                                                 v
~~~
{: title="Initial Configuration Retrieval.  The server returns the
requested configuration, annotated with txid values.  The most
recent change seems to have been an update to the R8 and
R9 source-port."}

NOTE: In the call flow examples we are using a 4-digit, monotonously
increasing integer as txid.  This is convenient and enhances
readability of the examples, but does not reflect a typical
implementation.  Servers may assign values randomly.  In general,
no information can be derived by observing that some txid value is
numerically or lexicographically lower than another txid value.
The only operation defined on a pair of txid values is testing them
for equality.

## Subsequent Configuration Retrieval

Clients MAY request the server to return txid values in the response
by adding one or more txid values received previously in get-config or
get-data requests.

When a NETCONF server receives a get-config or get-data request
containing a node with a client specified txid value, there are
several different cases:

* The node is not a versioned node, i.e. the server does not
maintain a txid value for this node.  In this case, the server
MUST look up the closest ancestor that is a versioned node, and
use the txid value of that node as the txid value of this node in
the further handling below.  The datastore root is always a
versioned node.

* The client specified txid value is different than the server's
txid value for this node.  In this case the server MUST return
the contents as it would otherwise have done, adding the txid values
of all child versioned nodes to the response.  In case the client
has specified txid values for some child nodes, then these
cases MUST be re-evaluated for those child nodes.

* The client specified txid
value matches the server's txid value.  In this case the server MUST
return the node decorated with a special "txid-match" txid value
(e.g. "=") to the matching node, pruning any value and child nodes.
A server MUST NOT ever use the txid-match value (e.g. "=") as an
actual txid value.

For list elements, pruning child nodes means that top-level
key nodes MUST be included in the response, and other child nodes
MUST NOT be included.  For containers, child nodes MUST NOT
be included.

~~~ call-flow
     Client                                            Server
       |                                                 |
       |   ------------------------------------------>   |
       |   get-config                                    |
       |     acls (txid: 5152)                           |
       |       acl A1 (txid: 4711)                       |
       |         aces (txid: 4711)                       |
       |       acl A2 (txid: 5152)                       |
       |         aces (txid: 5152)                       |
       |                                                 |
       |   <------------------------------------------   |
       |   data                                          |
       |     acls (txid: =)                              |
       v                                                 v
~~~
{: title="Response Pruning.  Client sends get-config request with
known txid values.  Server prunes response where txid matches
expectations."}

~~~ call-flow
     Client                                            Server
       |                                                 |
       |   ------------------------------------------>   |
       |   get-config                                    |
       |     acls (txid: 5152)                           |
       |       acl A1 (txid: 4711)                       |
       |       acl A2 (txid: 5152)                       |
       |                                                 |
       |   <------------------------------------------   |
       |   data                                          |
       |     acls (txid: 6614)                           |
       |       acl A1 (txid: =)                          |
       |       acl A2 (txid: 6614)                       |
       |         aces (txid: 6614)                       |
       |           ace R7 (txid: 4711)                   |
       |             matches ipv4 dscp AF11              |
       |           ace R8 (txid: 5152)                   |
       |             matches udp source-port port 22     |
       |           ace R9 (txid: 6614)                   |
       |             matches tcp source-port port 830    |
       v                                                 v
~~~
{: title="Out of band change detected.  Client sends get-config
request with known txid values.  Server provides update where
changes have happened.  Specifically ace R8 is returned since
ace R8 is a child of a node for which the request had a
different txid than the server, and the client did not specify
any matching txid for the ace R8 node."}

~~~ call-flow
     Client                                            Server
       |                                                 |
       |   ------------------------------------------>   |
       |   get-config                                    |
       |     acls                                        |
       |       acls A2                                   |
       |         aces                                    |
       |           ace R7                                |
       |             matches                             |
       |               ipv4                              |
       |                 dscp (txid: 4711)               |
       |                                                 |
       |   <------------------------------------------   |
       |   data                                          |
       |     acls                                        |
       |       acl A2                                    |
       |         aces                                    |
       |           ace R7                                |
       |             matches                             |
       |               ipv4                              |
       |                 dscp (txid: =)                  |
       v                                                 v
~~~
{: title="Versioned nodes.  Server lookup of dscp txid gives
4711, as closest ancestor is ace R7 with txid 4711.  Since the
server's and client's txid match, the etag value is '=', and
the leaf value is pruned."}

## Configuration Retrieval from the Candidate Datastore

When a client retrieves the configuration from the candidate
datastore, some of the configuration nodes may hold the same data as
the corresponding node in the running datastore.  In such cases, the
server MUST return the same txid value for nodes in the candidate
datastore as in the running datastore.

If a node in the candidate datastore holds different data than in the
running datastore, the server has a choice of what to return.

- The server MAY return a txid-unknown value (e.g. "!").  This may
be convenient in servers that do not know a priori what txids will
be used in a future, possible commit of the canidate.

- If the txid-unknown value is not returned, the server MUST return
 he txid value the node will have after commit, assuming the client
 makes no further changes of the candidate datastore.

See the example in [Transactions toward the Candidate
Datastore](#transactions-toward-the-candidate-datastore).

## Conditional Transactions

Conditional transactions are useful when a client is interested
to make a configuration change, being sure that relevant parts of
the server configuration have not changed since the client last
inspected it.

By supplying the latest txid values known to the client
in its change requests (edit-config etc.), it can request the server
to reject the transaction in case any relevant changes have occurred
at the server that the client is not yet aware of.

This allows a client to reliably compute and send confiuguration
changes to a server without either acquiring a global datastore lock
for a potentially extended period of time, or risk that a change
from another client disrupts the intent in the time window between a
read (get-config etc.) and write (edit-config etc.) operation.

Clients that are also interested to know the txid assigned to the
modified versioned nodes in the model immediately in the
response could set a flag in the rpc message to request the server
to return the new txid with the ok message.

~~~ call-flow
     Client                                            Server
       |                                                 |
       |   ------------------------------------------>   |
       |   edit-config (request new txid in response)    |
       |     config (txid: 5152)                         |
       |       acls (txid: 5152)                         |
       |         acl A1 (txid: 4711)                     |
       |           aces (txid: 4711)                     |
       |             ace R1 (txid: 4711)                 |
       |               matches ipv4 protocol tcp         |
       |                                                 |
       |   <------------------------------------------   |
       |   ok (txid: 7688)                               |
       v                                                 v
~~~
{: title="Conditional transaction towards the Running datastore
successfully executed.  As all the txid values specified by the
client matched those on the server, the transaction was successfully
executed."}

~~~ call-flow
     Client                                            Server
       |                                                 |
       |   ------------------------------------------>   |
       |   get-config                                    |
       |     acls (txid: ?)                              |
       |                                                 |
       |   <------------------------------------------   |
       |   data                                          |
       |     acls (txid: 7688)                           |
       |       acl A1 (txid: 7688)                       |
       |         aces (txid: 7688)                       |
       |           ace R1 (txid: 7688)                   |
       |             matches ipv4 protocol tcp           |
       |       acl A2 (txid: 6614)                       |
       |         aces (txid: 6614)                       |
       |           ace R7 (txid: 4711)                   |
       |             matches ipv4 dscp AF11              |
       |           ace R8 (txid: 5152)                   |
       |             matches udp source-port port 22     |
       |           ace R9 (txid: 6614)                   |
       |             matches tcp source-port port 830    |
       v                                                 v
~~~
{: title="For all leaf objects that were changed, and all their
ancestors, the txids are updated to the value returned in the ok
message."}

If the server rejects the transaction because one or more of the
configuration txid value(s) differs from the client's expectation,
the server MUST return at least one rpc-error with the following
values:

~~~
   error-tag:      operation-failed
   error-type:     protocol
   error-severity: error
~~~

Additionally, the error-info tag MUST contain an sx:structure
containing relevant details about one of the mismatching txids.
A server MAY send multiple rpc-errors when multiple txid mismatches
are detected.

~~~ call-flow
     Client                                            Server
       |                                                 |
       |   ------------------------------------------>   |
       |   edit-config                                   |
       |     config                                      |
       |       acls                                      |
       |         acl A1 (txid: 4711)                     |
       |           aces (txid: 4711)                     |
       |             ace R1 (txid: 4711)                 |
       |               ipv4 dscp AF22                    |
       |                                                 |
       |   <------------------------------------------   |
       |   rpc-error                                     |
       |     error-tag       operation-failed            |
       |     error-type      protocol                    |
       |     error-severity  error                       |
       |     error-info                                  |
       |       mismatch-path /acls/acl[A1]               |
       |       mismatch-etag-value 6912                  |
       v                                                 v
~~~
{: title="Conditional transaction that fails a txid check.  The
client wishes to ensure there has been no changes to the particular
acl entry it edits, and therefore sends the txid it knows for this
part of the configuration.  Since the txid has changed
(out of band), the server rejects the configuration change request
and reports an error with details about where the mismatch was
detected."}

## Transactions toward the Candidate Datastore

When working with the Candidate datastore, the txid validation happens
at commit time, rather than at individual edit-config or edit-data
operations.  Clients add their txid attributes to the configuration
payload the same way.  In case a client specifies different txid
values for the same element in successive edit-config or edit-data
operations, the txid value specified last MUST be used by the server
at commit time.

~~~ call-flow
     Client                                            Server
       |                                                 |
       |   ------------------------------------------>   |
       |   edit-config (operation: merge)                |
       |     config (txid: 5152)                         |
       |       acls (txid: 5152)                         |
       |         acl A1 (txid: 4711)                     |
       |           type ipv4                             |
       |                                                 |
       |   <------------------------------------------   |
       |   ok                                            |
       |                                                 |
       |   ------------------------------------------>   |
       |   edit-config (operation: merge)                |
       |     config                                      |
       |       acls                                      |
       |         acl A1                                  |
       |           aces (txid: 4711)                     |
       |             ace R1 (txid: 4711)                 |
       |               matches ipv4 protocol tcp         |
       |                                                 |
       |   <------------------------------------------   |
       |   ok                                            |
       |                                                 |
       |   ------------------------------------------>   |
       |   get-config                                    |
       |     config                                      |
       |       acls                                      |
       |         acl A1                                  |
       |           aces (txid: ?)                        |
       |                                                 |
       |   <------------------------------------------   |
       |     config                                      |
       |       acls                                      |
       |         acl A1                                  |
       |           aces (txid: 7688  or !)               |
       |             ace R1 (txid: 7688 or !)            |
       |               matches ipv4 protocol tcp         |
       |             ace R2 (txid: 2219)                 |
       |               matches ipv4 dscp 21              |
       |                                                 |
       |   ------------------------------------------>   |
       |   commit (request new txid in response)         |
       |                                                 |
       |   <------------------------------------------   |
       |   ok (txid: 7688)                               |
       v                                                 v
~~~
{: title="Conditional transaction towards the Candidate datastore
successfully executed.  As all the txid values specified by the
client matched those on the server at the time of the commit,
the transaction was successfully executed.  If a client issues a
get-config towards the candidate datastore, the server may choose
to return the special txid-unknown value (e.g. "!") or the txid
value that would be used if the candidate was committed without
further changes (if that txid value is known in advance by the
server)."}

## Dependencies within Transactions

YANG modules that contain when-statements referencing remote
parts of the model will cause the txid to change even in parts of the
data tree that were not modified directly.

Let's say there is an energy-example.yang module that defines a
mechanism for clients to request the server to measure the amount of
energy that is consumed by a given access control rule.  The
energy-example module augments the access control module as follows:

~~~ yang
  augment /acl:acls/acl:acl {
    when /energy-example:energy/energy-example:metering-enabled;
    leaf energy-tracing {
      type boolean;
      default false;
    }
    leaf energy-consumption {
      config false;
      type uint64;
      units J;
    }
  }
~~~

This means there is a system wide switch leaf metering-enabled in
energy-example which disables all energy measurements in the system when
set to false, and that there is a boolean leaf energy-tracing that
controls whether energy measurement is happening for each acl rule
individually.

In this example, we have an initial configuration like this:

~~~ call-flow
     Client                                            Server
       |                                                 |
       |   ------------------------------------------>   |
       |   get-config                                    |
       |     energy (txid: ?)                            |
       |     acls (txid: ?)                              |
       |                                                 |
       |   <------------------------------------------   |
       |   data (txid: 7688)                             |
       |     energy metering-enabled true (txid: 4711)   |
       |     acls (txid: 7688)                           |
       |       acl A1 (txid: 7688)                       |
       |         energy-tracing false                    |
       |         aces (txid: 7688)                       |
       |           ace R1 (txid: 7688)                   |
       |             matches ipv4 protocol tcp           |
       |       acl A2 (txid: 6614)                       |
       |         energy-tracing true                     |
       |         aces (txid: 6614)                       |
       |           ace R7 (txid: 4711)                   |
       |             matches ipv4 dscp AF11              |
       |           ace R8 (txid: 5152)                   |
       |             matches udp source-port port 22     |
       |           ace R9 (txid: 6614)                   |
       |             matches tcp source-port port 830    |
       v                                                 v
~~~
{: title="Initial configuration for the energy example.  Note the
energy metering-enabled leaf at the top and energy-tracing leafs
under each acl."}

At this point, a client updates metering-enabled to false.  This causes
the when-expression on energy-tracing to turn false, removing the leaf
entirely.  This counts as a configuration change, and the txid MUST be
updated appropriately.

~~~ call-flow
     Client                                            Server
       |                                                 |
       |   ------------------------------------------>   |
       |   edit-config (request new txid in response)    |
       |     config                                      |
       |       energy metering-enabled false             |
       |                                                 |
       |   <------------------------------------------   |
       |   ok (txid: 9118)                               |
       v                                                 v
~~~
{: title="Transaction changing a single leaf.  This leaf is the target
of a when-statement, however, which means other leafs elsewhere may
be indirectly modified by this change.  Such indirect changes will also
result in txid changes."}

After the transaction above, the new configuration state has the
energy-tracing leafs removed.

~~~ call-flow
     Client                                            Server
       |                                                 |
       |   ------------------------------------------>   |
       |   get-config                                    |
       |     energy (txid: ?)                            |
       |     acls (txid: ?)                              |
       |                                                 |
       |   <------------------------------------------   |
       |   data (txid: 9118)                             |
       |     energy metering-enabled false (txid: 9118)  |
       |     acls (txid: 9118)                           |
       |       acl A1 (txid: 9118)                       |
       |         aces (txid: 7688)                       |
       |           ace R1 (txid: 7688)                   |
       |             matches ipv4 protocol tcp           |
       |       acl A2 (txid: 9118)                       |
       |         aces (txid: 6614)                       |
       |           ace R7 (txid: 4711)                   |
       |             matches ipv4 dscp AF11              |
       |           ace R8 (txid: 5152)                   |
       |             matches udp source-port port 22     |
       |           ace R9 (txid: 6614)                   |
       |             matches tcp source-port port 830    |
       v                                                 v
~~~
{: title="The txid for the energy subtree has changed since that was
the target of the edit-config.  The txids of the ACLs have also
changed since the energy-tracing leafs are now removed by the
now false when-expression."}

## Other NETCONF Operations

discard-changes
: The discard-changes operation resets the candidate datastore to the
contents of the running datastore.  The server MUST ensure the
txid values in the candidate datastore get the same txid values
as in the running datastore when this operation runs.

copy-config
: The copy-config operation can be used to copy contents between
datastores.  The server MUST ensure the txid values are retained
and changed as if the data being copied had been sent in through an
edit-config operation.

delete-config
: The server MUST ensure the datastore txid value is changed, unless it
was already empty.

commit
: At commit, with regards to the txid values, the server MUST
treat the contents of the candidate datastore as if any txid
value provided by the client when updating the candidate was provided
in a single edit-config towards the running datastore.  If the
transaction is rejected due to txid value mismatch,
an rpc-error as described in section
[Conditional Transactions](#conditional-transactions) MUST be sent.

## YANG-Push Subscriptions

A client issuing a YANG-Push establish-subscription or
modify-subscription request towards a server that supports both
YANG-Push {{RFC8641}} and a txid
mechanism MAY request that the server provides updated txid values in
YANG-Push subscription updates.

# Txid Mechanisms

This document defines two txid mechanisms:

- The etag attribute txid mechanism

- The last-modified attribute txid mechanism

Servers implementing this specification MUST support the etag
attribute txid mechanism and MAY support the last-modified
attribute txid mechanism.

Section [NETCONF Txid Extension](#netconf-txid-extension) describes
the logic that governs all txid mechanisms.  This section describes
the mapping from the generic logic to specific mechanism and encoding.

If a client uses more than one txid mechanism, such as both etag and
last-modified in a particular message to a server, or patricular
commit, the result is undefined.

## The etag attribute txid mechanism

The etag txid mechanism described in this section is centered around
a meta data XML attribute called "etag".  The etag attribute is
defined in the namespace "urn:ietf:params:xml:ns:netconf:txid:1.0".
The etag attribute is added to XML elements in the NETCONF payload
in order to indicate the txid value for the YANG node represented by
the element.

NETCONF servers that support this extension MUST announce the
capability "urn:ietf:params:netconf:capability:txid:etag:1.0".

The etag attribute values are opaque UTF-8 strings chosen freely,
except that the etag string must not contain space, backslash
or double quotes. The point of this restriction is to make it easy to
reuse implementations that adhere to section 2.3.1 in
{{RFC7232}}.  The probability
SHOULD be made very low that an etag value that has been used
historically by a server is used again by that server if the
configuration is different.

It is RECOMMENDED that the same etag txid values are used across all
management interfaces (i.e. NETCONF, RESTCONF and any other the server
might implement), if it implements more than one.

The detailed rules for when to update the etag value are described in
section [General Txid Principles](#general-txid-principles).  These
rules are chosen to be consistent with the ETag mechanism in
RESTCONF, {{RFC8040}},
specifically sections 3.4.1.2, 3.4.1.3 and 3.5.2.

## The last-modified attribute txid mechanism

The last-modified txid mechanism described in this section is
centered around a meta data XML attribute called "last-modified".
The last-modified attribute is defined in the namespace
"urn:ietf:params:xml:ns:netconf:txid:1.0".  The last-modified
attribute is added to XML elements in the NETCONF payload in
order to indicate the txid value for the YANG node represented by
the element.

NETCONF servers that support this extension MUST announce the
capability
"urn:ietf:params:netconf:capability:txid:last-modified:1.0".

The last-modified attribute values are yang:date-and-time values as
defined in ietf-yang-types.yang, {{RFC6991}}.

"2022-04-01T12:34:56.123456Z" is an example of what this time stamp
format looks like.  It is RECOMMENDED that the time stamps provided
by the server to closely match the real world clock.  Servers
MUST ensure the timestamps provided are monotonously increasing for
as long as the server's operation is maintained.

It is RECOMMENDED that server implementors choose the number of
digits of precision used for the fractional second timestamps
high enough so that there is no risk that multiple transactions on
the server would get the same timestamp.

It is RECOMMENDED that the same last-modified txid values are used
across all management interfaces (i.e. NETCONF and any other the
server might implement), except RESTCONF.

RESTCONF, as defined in
{{RFC8040}},
is using a different format for the time stamps which is
limited to one second resolution.  Server implementors that support
the Last-Modified txid mechanism over both RESTCONF and other
management protocols are RECOMMENDED to use Last-Modified timestamps
that match the point in time referenced over RESTCONF, with the
fractional seconds part added.

The detailed rules for when to update the last-modified value are
described in section
[General Txid Principles](#general-txid-principles).  These rules
are chosen to be consistent with the Last-Modified mechanism in
RESTCONF, {{RFC8040}},
specifically sections 3.4.1.1, 3.4.1.3 and 3.5.1.

## Common features to both etag and last-modified txid mechanisms

### Clients

Clients MAY add etag or last-modified attributes to zero or
more individual elements in the get-config or get-data filter, in
which case they pertain to the subtree(s) rooted at the element(s)
with the attributes.

Clients MAY also add such attributes directly to the get-config or
get-data tags (e.g. if there is no filter), in which case it
pertains to the txid value of the datastore root.

Clients might wish to send a txid value that is guaranteed to never
match a server constructed txid.  With both the etag and
last-modified txid mechanisms, such a txid-request value is "?".

Clients MAY add etag or last-modified attributes to the payload
of edit-config or edit-data requests, in which case they indicate
the client's txid value of that element.

Clients MAY request servers that also implement YANG-Push to return
configuration change subsription updates with etag or
last-modified txid attributes.  The client requests this service by
adding a with-etag or with-last-modified flag with the value 'true'
to the subscription request or yang-push configuration.  The server
MUST then return such txids on the YANG Patch edit tag and to the
child elements of the value tag.  The txid attribute on the edit tag
reflects the txid associated with the changes encoded in this edit
section, as well as parent nodes.  Later edit sections in the same
push-update or push-change-update may still supercede the txid value
for some or all of the nodes in the current edit section.

### Servers

Servers returning txid values in get-config, edit-config, get-data,
edit-data and commit operations MUST do so by adding etag and/or
last-modified txid attributes to the data and ok tags.  When
servers prune output due to a matching txid value, the server
MUST add a txid-match attribute to the pruned element, and MUST set
the attribute value to "=", and MUST NOT send any element value.

Servers returning a txid mismatch error MUST return an rpc-error
as defined in section
[Conditional Transactions](#conditional-transactions) with an
error-info tag containing a txid-value-mismatch-error-info
structure.

When servers return txid values in get-config and get-data operations
towards the candidate datastore, the txid values returned MUST adhere
to the following rules:

- If the versioned node holds the same data as in the running
datastore, the same txid value as the versioned node in running
MUST be used.

- If the versioned node is different in the candidata store
than in the running datastore, the server has a choice of what
to return. The server MAY return the special "txid-unknown" value "!".
If the txid-unknown value is not returned, the server MUST return
the txid value the versioned node will have if the client decides to commit the candidate datastore without further updates.

### Namespaces and Attributes Placement

The txid attributes are valid on the following NETCONF tags,
where xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0",
xmlns:ncds="urn:ietf:params:xml:ns:yang:ietf-netconf-nmda",
xmlns:sn="urn:ietf:params:xml:ns:yang:ietf-subscribed-notifications",
xmlns:yp="urn:ietf:params:xml:ns:yang:ietf-yang-patch" and
xmlns:ypatch="urn:ietf:params:xml:ns:yang:ietf-yang-patch":

In client messages sent to a server:

- /nc:rpc/nc:get-config

- /nc:rpc/nc:get-config/nc:filter//*

- /nc:rpc/ncds:get-data

- /nc:rpc/ncds:get-data/ncds:subtree-filter//*

- /nc:rpc/ncds:get-data/ncds:xpath-filter//*

- /nc:rpc/nc:edit-config/nc:config

- /nc:rpc/nc:edit-config/nc:config//*

- /nc:rpc/ncds:edit-data/ncds:config

- /nc:rpc/ncds:edit-data/ncds:config//*

In server messages sent to a client:

- /nc:rpc-reply/nc:data

- /nc:rpc-reply/nc:data//*

- /nc:rpc-reply/ncds:data

- /nc:rpc-reply/ncds:data//*

- /nc:rpc-reply/nc:ok

- /yp:push-update/yp:datastore-contents/ypatch:yang-patch/
  ypatch:edit

- /yp:push-update/yp:datastore-contents/ypatch:yang-patch/
  ypatch:edit/ypatch:value//*

- /yp:push-change-update/yp:datastore-contents/ypatch:yang-patch/
  ypatch:edit

- /yp:push-change-update/yp:datastore-contents/ypatch:yang-patch/
  ypatch:edit/ypatch:value//*

# Txid Mechanism Examples

## Initial Configuration Response

### With etag

NOTE: In the etag examples below, we have chosen to use a txid
value consisting of "nc" followed by a monotonously increasing
integer.  This is convenient for the reader trying to make sense
of the examples, but is not an implementation requirement.  An
etag would often be implemented as a "random" string of characters,
with no comes-before/after relation defined.

To retrieve etag attributes across the entire NETCONF server
configuration, a client might send:

~~~ xml
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="1"
     xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <get-config txid:etag="?"/>
</rpc>
~~~

The server's reply might then be:

~~~ xml
<rpc-reply message-id="1"
           xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <data txid:etag="nc5152">
    <acls xmlns=
            "urn:ietf:params:xml:ns:yang:ietf-access-control-list"
          txid:etag="nc5152">
      <acl txid:etag="nc4711">
        <name>A1</name>
        <aces txid:etag="nc4711">
          <ace txid:etag="nc4711">
            <name>R1</name>
            <matches>
              <ipv4>
                <protocol>udp</protocol>
              </ipv4>
            </matches>
          </ace>
        </aces>
      </acl>
      <acl txid:etag="nc5152">
        <name>A2</name>
        <aces txid:etag="nc5152">
          <ace txid:etag="nc4711">
            <name>R7</name>
            <matches>
              <ipv4>
                <dscp>AF11</dscp>
              </ipv4>
            </matches>
          </ace>
          <ace txid:etag="nc5152">
            <name>R8</name>
            <matches>
              <udp>
                <source-port>
                  <port>22</port>
                </source-port>
              </udp>
            </matches>
          </ace>
          <ace txid:etag="nc5152">
            <name>R9</name>
            <matches>
              <tcp>
                <source-port>
                  <port>22</port>
                </source-port>
              </tcp>
            </matches>
          </ace>
        </aces>
      </acl>
    </acls>
    <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm"
          txid:etag="nc3072">
      <groups txid:etag="nc3072">
        <group txid:etag="nc3072">
          <name>admin</name>
          <user-name>sakura</user-name>
          <user-name>joe</user-name>
        </group>
      </groups>
    </nacm>
  </data>
</rpc>
~~~

To retrieve etag attributes for a specific ACL using an xpath
filter, a client might send:

~~~ xml
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="2"
     xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <get-config>
    <source>
      <running/>
    </source>
    <filter type="xpath"
      xmlns:acl=
        "urn:ietf:params:xml:ns:yang:ietf-access-control-list"
      select="/acl:acls/acl:acl[acl:name='A1']"
      txid:etag="?"/>
  </get-config>
</rpc>
~~~

To retrieve etag attributes for "acls", but not for "nacm",
a client might send:

~~~ xml
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="3"
     xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <get-config>
    <source>
      <running/>
    </source>
    <filter>
      <acls
        xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list"
        txid:etag="?"/>
      <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm"/>
    </filter>
  </get-config>
</rpc>
~~~

If the server considers "acls", "acl", "aces" and "acl" to be
versioned nodes, the server's response to the request above
might look like:

~~~ xml
<rpc-reply message-id="3"
           xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <data>
    <acls xmlns=
            "urn:ietf:params:xml:ns:yang:ietf-access-control-list"
          txid:etag="nc5152">
      <acl txid:etag="nc4711">
        <name>A1</name>
        <aces txid:etag="nc4711">
          <ace txid:etag="nc4711">
            <name>R1</name>
            <matches>
              <ipv4>
                <protocol>udp</protocol>
              </ipv4>
            </matches>
          </ace>
        </aces>
      </acl>
      <acl txid:etag="nc5152">
        <name>A2</name>
        <aces txid:etag="nc5152">
          <ace txid:etag="nc4711">
            <name>R7</name>
            <matches>
              <ipv4>
                <dscp>AF11</dscp>
              </ipv4>
            </matches>
          </ace>
          <ace txid:etag="nc5152">
            <name>R8</name>
            <matches>
              <udp>
                <source-port>
                  <port>22</port>
                </source-port>
              </udp>
            </matches>
          </ace>
          <ace txid:etag="nc5152">
            <name>R9</name>
            <matches>
              <tcp>
                <source-port>
                  <port>22</port>
                </source-port>
              </tcp>
            </matches>
          </ace>
        </aces>
      </acl>
    </acls>
    <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm"/>
      <groups>
        <group>
          <name>admin</name>
          <user-name>sakura</user-name>
          <user-name>joe</user-name>
        </group>
      </groups>
    </nacm>
  </data>
</rpc>
~~~

### With last-modified

To retrieve last-modified attributes for "acls", but not for "nacm",
a client might send:

~~~ xml
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="4"
     xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <get-config>
    <source>
      <running/>
    </source>
    <filter>
      <acls
        xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list"
        txid:last-modified="?"/>
      <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm"/>
    </filter>
  </get-config>
</rpc>
~~~

If the server considers "acls", "acl", "aces" and "acl" to be
versioned nodes, the server's response to the request above
might look like:

~~~ xml
<rpc-reply message-id="4"
           xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <data>
    <acls
      xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list"
      txid:last-modified="2022-04-01T12:34:56.789012Z">
      <acl txid:last-modified="2022-03-20T16:20:11.333444Z">
        <name>A1</name>
        <aces txid:last-modified="2022-03-20T16:20:11.333444Z">
          <ace txid:last-modified="2022-03-20T16:20:11.333444Z">
            <name>R1</name>
            <matches>
              <ipv4>
                <protocol>udp</protocol>
              </ipv4>
            </matches>
          </ace>
        </aces>
      </acl>
      <acl txid:last-modified="2022-04-01T12:34:56.789012Z">
        <name>A2</name>
        <aces txid:last-modified="2022-04-01T12:34:56.789012Z">
          <ace txid:last-modified="2022-03-20T16:20:11.333444Z">
            <name>R7</name>
            <matches>
              <ipv4>
                <dscp>AF11</dscp>
              </ipv4>
            </matches>
          </ace>
          <ace txid:last-modified="2022-04-01T12:34:56.789012Z">
            <name>R8</name>
            <matches>
              <udp>
                <source-port>
                  <port>22</port>
                </source-port>
              </udp>
            </matches>
          </ace>
          <ace txid:last-modified="2022-04-01T12:34:56.789012Z">
            <name>R9</name>
            <matches>
              <tcp>
                <source-port>
                  <port>22</port>
                </source-port>
              </tcp>
            </matches>
          </ace>
        </aces>
      </acl>
    </acls>
    <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm"/>
      <groups>
        <group>
          <name>admin</name>
          <user-name>sakura</user-name>
          <user-name>joe</user-name>
        </group>
      </groups>
    </nacm>
  </data>
</rpc>
~~~

## Configuration Response Pruning

A NETCONF client that already knows some txid values MAY request that
the configuration retrieval request is pruned with respect to the
client's prior knowledge.

To retrieve only changes for "acls" that do not have the
last known etag txid value, a client might send:

~~~ xml
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="6"
     xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <get-config>
    <source>
      <running/>
    </source>
    <filter>
      <acls
        xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list"
        txid:etag="nc5152">
        <acl txid:etag="nc4711">
          <name>A1</name>
          <aces txid:etag="nc4711"/>
        </acl>
        <acl txid:etag="nc5152">
          <name>A2</name>
          <aces txid:etag="nc5152"/>
        </acl>
    </filter>
  </get-config>
</rpc>
~~~

Assuming the NETCONF server configuration is the same as
in the previous rpc-reply example, the server's response to request
above might look like:

~~~ xml
<rpc-reply message-id="6"
           xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <data>
    <acls
      xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list"
      txid:etag="="/>
  </data>
</rpc>
~~~

Or, if a configuration change has taken place under /acls since the
client was last updated, the server's response may look like:

~~~ xml
<rpc-reply message-id="6"
           xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <data>
    <acls
      xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list"
      txid:etag="nc6614">
      <acl txid:etag="=">
        <name>A1</name>
      </acl>
      <acl txid:etag="nc6614">
        <name>A2</name>
        <aces txid:etag="nc6614">
          <ace txid:etag="nc4711">
            <name>R7</name>
            <matches>
              <ipv4>
                <dscp>AF11</dscp>
              </ipv4>
            </matches>
          </ace>
          <ace txid:etag="nc5152">
            <name>R8</name>
            <matches>
              <ipv4>
                <source-port>
                  <port>22</port>
                </source-port>
              </ipv4>
            </matches>
          </ace>
          <ace txid:etag="nc6614">
            <name>R9</name>
            <matches>
              <ipv4>
                <source-port>
                  <port>830</port>
                </source-port>
              </ipv4>
            </matches>
          </ace>
        </aces>
      </acl>
    </acls>
  </data>
</rpc>
~~~

In case the client provides a txid value for a non-versioned node,
the server needs to treat the node as having the same txid value as
the closest ancestor that does have a txid value.

~~~ xml
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="7"
     xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <get-config>
    <source>
      <running/>
    </source>
    <filter>
      <acls
        xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list">
        <acl>
          <name>A2</name>
          <aces>
            <ace>
              <name>R7</name>
              <matches>
                <ipv4>
                  <dscp txid:etag="nc4711"/>
                </ipv4>
              </matches>
            </ace>
          </aces>
        </acl>
      </acls>
    </filter>
  </get-config>
</rpc>
~~~

If a txid value is specified for a leaf, and the txid value matches,
the leaf value is pruned.

~~~ xml
<rpc-reply message-id="7"
           xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <data>
    <acls
      xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list">
      <acl>
        <name>A2</name>
        <aces>
          <ace>
            <name>R7</name>
            <matches>
              <ipv4>
                <dscp txid:etag="="/>
              </ipv4>
            </matches>
          </ace>
        </aces>
      </acl>
    </acls>
  </data>
</rpc-reply>
~~~

## Configuration Change

A client that wishes to update the ace R1 protocol to tcp might send:

~~~ xml
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="8">
  <edit-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
               xmlns:ietf-netconf-txid=
                "urn:ietf:params:xml:ns:yang:ietf-netconf-txid">
    <target>
      <running/>
    </target>
    <test-option>test-then-set</test-option>
    <ietf-netconf-txid:with-etag>true<ietf-netconf-txid:with-etag>
    <config>
      <acls
        xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list"
        txid:etag="nc5152">
        <acl txid:etag="nc4711">
          <name>A1</name>
          <aces txid:etag="nc4711">
            <ace txid:etag="nc4711">
              <matches>
                <ipv4>
                  <protocol>tcp</protocol>
                </ipv4>
              </matches>
            </ace>
          </aces>
        </acl>
      </acls>
    </config>
  </edit-config>
</rpc>
~~~

The server would update the protocol leaf in the running datastore,
and return an rpc-reply as follows:

~~~ xml
<rpc-reply message-id="8"
           xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <ok txid:etag="nc7688"/>
</rpc-reply>
~~~

A subsequent get-config request for "acls", with txid:etag="?" might
then return:

~~~ xml
<rpc-reply message-id="9"
           xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <data>
    <acls
      xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list"
      txid:etag="nc7688">
      <acl txid:etag="nc7688">
        <name>A1</name>
        <aces txid:etag="nc7688">
          <ace txid:etag="nc7688">
            <name>R1</name>
            <matches>
              <ipv4>
                <protocol>tcp</protocol>
              </ipv4>
            </matches>
          </ace>
        </aces>
      </acl>
      <acl txid:etag="nc6614">
        <name>A2</name>
        <aces txid:etag="nc6614">
          <ace txid:etag="nc4711">
            <name>R7</name>
            <matches>
              <ipv4>
                <dscp>AF11</dscp>
              </ipv4>
            </matches>
          </ace>
          <ace txid:etag="nc5152">
            <name>R8</name>
            <matches>
              <udp>
                <source-port>
                  <port>22</port>
                </source-port>
              </udp>
            </matches>
          </ace>
          <ace txid:etag="nc6614">
            <name>R9</name>
            <matches>
              <tcp>
                <source-port>
                  <port>830</port>
                </source-port>
              </tcp>
            </matches>
          </ace>
        </aces>
      </acl>
    </acls>
  </data>
</rpc>
~~~

In case the server at this point received a configuration change from
another source, such as a CLI operator, removing ace R8 and R9 in
acl A2, a subsequent get-config request for acls, with txid:etag="?"
might then return:

~~~ xml
<rpc-reply message-id="9"
           xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <data>
    <acls
      xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list"
      txid:etag="cli2222">
      <acl txid:etag="nc7688">
        <name>A1</name>
        <aces txid:etag="nc7688">
          <ace txid:etag="nc7688">
            <name>R1</name>
            <matches>
              <ipv4>
                <protocol>tcp</protocol>
              </ipv4>
            </matches>
          </ace>
        </aces>
      </acl>
      <acl txid:etag="cli2222">
        <name>A2</name>
        <aces txid:etag="cli2222">
          <ace txid:etag="nc4711">
            <name>R7</name>
            <matches>
              <ipv4>
                <dscp>AF11</dscp>
              </ipv4>
            </matches>
          </ace>
        </aces>
      </acl>
    </acls>
  </data>
</rpc>
~~~

## Conditional Configuration Change

If a client wishes to delete acl A1 if and only if its configuration
has not been altered since this client last synchronized its
configuration with the server, at which point it received the etag
"nc7688" for acl A1, regardless of any possible changes to other
acls, it might send:

~~~ xml
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="10"
     xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0"
     xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0"
     xmlns:ietf-netconf-txid=
       "urn:ietf:params:xml:ns:yang:ietf-netconf-txid">
  <edit-config>
    <target>
      <runnign/>
    </target>
    <test-option>test-then-set</test-option>
    <ietf-netconf-txid:with-etag>true<ietf-netconf-txid:with-etag>
    <config>
      <acls xmlns=
          "urn:ietf:params:xml:ns:yang:ietf-access-control-list">
        <acl nc:operation="delete"
             txid:etag="nc7688">
          <name>A1</name>
        </acl>
      </acls>
    </config>
  </edit-config>
</rpc>
~~~

If acl A1 now has the etag txid value "nc7688", as expected by the
client, the transaction goes through, and the server responds
something like:

~~~ xml
<rpc-reply message-id="10"
           xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <ok txid:etag="nc8008"/>
</rpc-reply>
~~~

A subsequent get-config request for acls, with txid:etag="?" might
then return:

~~~ xml
<rpc-reply message-id="11"
           xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <data>
    <acls
      xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list"
      txid:etag="nc8008">
      <acl txid:etag="cli2222">
        <name>A2</name>
        <aces txid:etag="cli2222">
          <ace txid:etag="nc4711">
            <name>R7</name>
            <matches>
              <ipv4>
                <dscp>AF11</dscp>
              </ipv4>
            </matches>
          </ace>
        </aces>
      </acl>
    </acls>
  </data>
</rpc>
~~~

In case acl A1 did not have the expected etag txid value "nc7688",
when the server processed this request, it rejects the transaction,
and might send:

~~~ xml
<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:acl=
            "urn:ietf:params:xml:ns:yang:ietf-access-control-list"
           xmlns:ietf-netconf-txid=
             "urn:ietf:params:xml:ns:yang:ietf-netconf-txid"
           message-id="11">
  <rpc-error>
    <error-type>protocol</error-type>
    <error-tag>operation-failed</error-tag>
    <error-severity>error</error-severity>
    <error-info>
      <ietf-netconf-txid:txid-value-mismatch-error-info>
        <ietf-netconf-txid:mismatch-path>
          /acl:acls/acl:acl[acl:name="A1"]
        </ietf-netconf-txid:mismatch-path>
        <ietf-netconf-txid:mismatch-etag-value>
          cli6912
        </ietf-netconf-txid:mismatch-etag-value>
      </ietf-netconf-txid:txid-value-mismatch-error-info>
    </error-info>
  </rpc-error>
</rpc-reply>
~~~

## Reading from the Candidate Datastore

Let's assume that a get-config towards the running datastore
currently contains the following data and txid values:

~~~ xml
<rpc-reply message-id="12"
           xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <data>
    <acls
      xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list"
      txid:etag="nc4711">
      <acl txid:etag="nc4711">
        <name>A1</name>
        <aces txid:etag="nc4711">
          <ace txid:etag="nc4711">
            <name>R1</name>
            <matches>
              <ipv4>
                <protocol>udp</protocol>
              </ipv4>
            </matches>
          </ace>
          <ace txid:etag="nc2219">
            <name>R2</name>
            <matches>
              <ipv4>
                <dscp>21</dscp>
              </ipv4>
            </matches>
          </ace>
        </aces>
      </acl>
    </acls>
  </data>
</rpc-reply>
~~~

A client issues discard-changes (to make the candidate datastore
equal to the running datastore), and issues an edit-config to
change the R1 protocol from udp to tcp, and then executes a
get-config with the txid-request attribute "?" set on the acl A1,
the server might respond:

~~~ xml
<rpc-reply message-id="13"
           xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
           xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <data>
    <acls
      xmlns="urn:ietf:params:xml:ns:yang:ietf-access-control-list">
      <acl txid:etag="!">
        <name>A1</name>
        <aces txid:etag="!">
          <ace txid:etag="!">
            <name>R1</name>
            <matches>
              <ipv4>
                <protocol>tcp</protocol>
              </ipv4>
            </matches>
          </ace>
          <ace txid:etag="nc2219">
            <name>R2</name>
            <matches>
              <ipv4>
                <dscp>21</dscp>
              </ipv4>
            </matches>
          </ace>
        </aces>
      </acl>
    </acls>
  </data>
</rpc-reply>
~~~

Here, the txid-unknown value "!" is sent by the server.  This
particular server implementation does not know beforehand which
txid value would be used for this versioned node after commit.
It will be a value different from the current corresponding
txid value in the running datastore.

In case the server is able to predict the txid value that would
be used for the versioned node after commit, it could respond
with that value instead.  Let's say the server knows the txid
would be "7688" if the candidate datastore was committed without
further changes, then it would respond with that value in each
place where the example shows "!" above.

## Using etags with Other NETCONF Operations

The client MAY request that the new etag txid value is returned as an
attribute on the ok response for a successful commit.  The client
requests this by adding with-etag to the commit operation.

For example, a client might send:

~~~ xml
<rpc message-id="14"
    xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
    xmlns:ietf-netconf-txid=
      "urn:ietf:params:xml:ns:yang:ietf-netconf-txid"
  <commit>
    <ietf-netconf-txid:with-etag>true<ietf-netconf-txid:with-etag>
  </commit>
</rpc>
~~~

Assuming the server accepted the transaction, it might respond:

~~~ xml
<rpc-reply message-id="15"
    xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
    xmlns:txid="urn:ietf:params:xml:ns:netconf:txid:1.0">
  <ok txid:etag="nc8008"/>
</rpc-reply>
~~~

## YANG-Push

A client MAY request that the updates for one or more YANG Push
subscriptions are annotated with the txid values.  The request might
look like this:

~~~ xml
<netconf:rpc message-id="16"
             xmlns:netconf="urn:ietf:params:xml:ns:netconf:base:1.0">
  <establish-subscription
      xmlns=
        "urn:ietf:params:xml:ns:yang:ietf-subscribed-notifications"
      xmlns:yp="urn:ietf:params:xml:ns:yang:ietf-yang-push"
      xmlns:ietf-netconf-txid-yp=
        "urn:ietf:params:xml:ns:yang:ietf-txid-yang-push">
    <yp:datastore
        xmlns:ds="urn:ietf:params:xml:ns:yang:ietf-datastores">
      ds:running
    </yp:datastore>
    <yp:datastore-xpath-filter
        xmlns:acl=
          "urn:ietf:params:xml:ns:yang:ietf-access-control-list">
      /acl:acls
    </yp:datastore-xpath-filter>
    <yp:periodic>
      <yp:period>500</yp:period>
    </yp:periodic>
    <ietf-netconf-txid-yp:with-etag>
      true
    </ietf-netconf-txid-yp:with-etag>
  </establish-subscription>
</netconf:rpc>
~~~

In case a client wishes to modify a previous subscription request in
order to no longer receive YANG Push subscription updates, the request
might look like this:

~~~ xml
<rpc message-id="17"
    xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <modify-subscription
      xmlns=
        "urn:ietf:params:xml:ns:yang:ietf-subscribed-notifications"
      xmlns:yp="urn:ietf:params:xml:ns:yang:ietf-yang-push"
      xmlns:ietf-netconf-txid-yp=
        "urn:ietf:params:xml:ns:yang:ietf-txid-yang-push">
    <id>1011</id>
    <yp:datastore
        xmlns:ds="urn:ietf:params:xml:ns:yang:ietf-datastores">
      ds:running
    </yp:datastore>
    <ietf-netconf-txid-yp:with-etag>
      false
    </ietf-netconf-txid-yp:with-etag>
  </modify-subscription>
</rpc>
~~~

A server might send a subscription update like this:

~~~ xml
<notification
  xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0">
  <eventTime>2022-04-04T06:00:24.16Z</eventTime>
  <push-change-update
      xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-push">
    <id>89</id>
    <datastore-changes>
      <yang-patch>
        <patch-id>0</patch-id>
        <edit txid:etag="nc8008">
          <edit-id>edit1</edit-id>
          <operation>delete</operation>
          <target xmlns:acl=
            "urn:ietf:params:xml:ns:yang:ietf-access-control-list">
            /acl:acls
          </target>
          <value>
            <acl xmlns=
              "urn:ietf:params:xml:ns:yang:ietf-access-control-list">
              <name>A1</name>
            </acl>
          </value>
        </edit>
      </yang-patch>
    </datastore-changes>
  </push-change-update>
</notification>
~~~

# YANG Modules

## Base module for txid in NETCONF

~~~~ yang
{::include yang/ietf-netconf-txid.yang}
~~~~
{: sourcecode-markers="true"
sourcecode-name="ietf-netconf-txid@2022-04-01.yang”}

## Additional support for txid in YANG-Push

~~~~ yang
{::include yang/ietf-netconf-txid-yang-push.yang}
~~~~
{: sourcecode-markers="true"
sourcecode-name="ietf-netconf-txid-yang-push@2022-04-01.yang”}

# Security Considerations

## NACM Access Control

NACM, {{RFC8341}}, access control
processing happens as usual, independently of any txid handling, if
supported by the server and enabled by the NACM configuration.

It should be pointed out however, that when txid information is added
to a reply, it may occasionally be possible for a client to deduce
that a configuration change has happened in some part of the
configuration to which it has no access rights.

For example, a client may notice that the root node txid has changed
while none of the subtrees it has access to have changed, and thereby
conclude that someone else has made a change to some part of the
configuration that is not acessible by the client.

### Hash-based Txid Algorithms

Servers that implement NACM and choose to implement a hash-based txid
algorithm over the configuration may reveal to a client that the
configuration of a subtree that the client has no access to is the
same as it was at an earlier point in time.

For example, a client with partial access to the configuration might
observe that the root node txid was 1234. After a few configuration
changes by other parties, the client may again observe that the root
node txid is 1234.  It may then deduce that the configuration is the
same as earlier, even in the parts of the configuration it has no
access to.

In some use cases, this behavior may be considered a feature, since it
allows a security client to verify that the configuration is the same
as expected, without transmitting or storing the actual configuration.

## Unchanged Configuration

It will also be possible for clients to deduce that a confiuration
change has not happened during some period, by simply observing that
the root node (or other subtree) txid remains unchanged.  This is
true regardless of NACM being deployed or choice of txid algorithm.

Again, there may be use cases where this behavior may be considered a
feature, since it allows a security client to verify that the
configuration is the same as expected, without transmitting or storing
the actual configuration.

# IANA Considerations

This document registers the following capability identifier URN in
the 'Network Configuration Protocol (NETCONF) Capability URNs'
registry:

~~~
  urn:ietf:params:netconf:capability:txid:1.0
~~~

This document registers three XML namespace URNs in the 'IETF XML
registry', following the format defined in
{{RFC3688}}.

~~~
  URI: urn:ietf:params:xml:ns:netconf:txid:1.0

  URI: urn:ietf:params:xml:ns:yang:ietf-netconf-txid

  URI: urn:ietf:params:xml:ns:yang:ietf-netconf-txid-yang-push

  Registrant Contact: The NETCONF WG of the IETF.

  XML: N/A, the requested URIs are XML namespaces.
~~~

This document registers two module names in the 'YANG Module Names'
registry, defined in {{RFC6020}}.

~~~
  name: ietf-netconf-txid

  prefix: ietf-netconf-txid

  namespace: urn:ietf:params:xml:ns:yang:ietf-netconf-txid

  RFC: XXXX
~~~

and

~~~
  name: ietf-netconf-txid-yp

  prefix: ietf-netconf-txid-yp

  namespace: urn:ietf:params:xml:ns:yang:ietf-netconf-txid-yang-push

  RFC: XXXX
~~~

# Changes

## Major changes in -03 since -02

* Changed the logic around how txids are handled in the candidate
datastore, both when reading (get-config, get-data) and writing
(edit-config, edit-data). Introduced a special "txid-unknown"
value "!".

* Changed the logic of copy-config to be similar to edit-config.

* Added content to security considerations.

* Updated language about error-info sent at txid mismatch in an
edit-config: error-info with mismatch details MUST be sent when
mismatch detected, and that the server can choose one of the txid
mismatch occurrences if there is more than one.

* Some rewording and minor additions for clarification, based
on mailing list feedback.

* Divided RFC references into normative and informative.

* Corrected a logic error in the second figure (figure 6) in the
"Conditional Transactions" section

## Major changes in -02 since -01

* A last-modified txid mechanism has been added (back).  This
mechanism aligns well with the Last-Modified mechanism defined in
RESTCONF {{RFC8040}},
but is not a carbon copy.

* YANG Push functionality has been added.  This allows YANG Push
users to receive txid updates as part of the configuration updates.
This functionality comes in a separate YANG module, to allow
implementors to cleanly keep all this functionality out.

* Changed name of "versioned elements". They are now called
"versioned nodes".

* Clarified txid behavior for transactions toward the Candidate
datastore, and some not so common situations, such
as when a client specifies a txid for a non-versioned node, and
when there are when-statement dependencies across subtrees.

* Examples provided for the abstract mechanism level with simple
message flow diagrams.

* More examples on protocol level, and with ietf-interfaces as
example target module replaced with ietf-access-control to reduce
confusion.

* Explicit list of XPaths to clearly state where etag or
last-modified attributes may be added by clients and servers.

* Document introduction restructured to remove duplication between
sections and to allow multiple (etag and last-modified) txid
mechanisms.

* Moved the actual YANG module code into proper module files that
are included in the source document.  These modules can be compiled
as proper modules without any extraction tools.

## Major changes in -01 since -00

* Updated the text on numerous points in order to answer questions
that appeared on the mailing list.

* Changed the document structure into a general transaction id part
and one etag specific part.

* Renamed entag attribute to etag, prefix to txid, namespace to
urn:ietf:params:xml:ns:yang:ietf-netconf-txid.

* Set capability string to
urn:ietf:params:netconf:capability:txid:1.0

* Changed YANG module name, namespace and prefix to match names above.

* Harmonized/slightly adjusted etag value space with RFC 7232 and
RFC 8040.

* Removed all text discussing etag values provided by the client
(although this is still an interesting idea, if you ask the author)

* Clarified the etag attribute mechanism, especially when it comes to
matching against non-versioned elements, its cascading upwards in the
tree and secondary effects from when- and choice-statements.

* Added a mechanism for returning the server assigned etag value in
get-config and get-data.

* Added section describing how the NETCONF discard-changes,
copy-config, delete-config and commit operations work with respect to
etags.

* Added IANA Considerations section.

* Removed all comments about open questions.

--- back

# Acknowledgments
{:numbered="false"}

The author wishes to thank Benoît Claise for making this work happen,
and the following individuals, who all provided helpful comments:
Per Andersson, Kent Watsen, Andy Bierman, Robert Wilton, Qiufang Ma,
Jason Sterne and Robert Varga.
