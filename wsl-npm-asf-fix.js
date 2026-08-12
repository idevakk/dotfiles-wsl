// WSL npm IPv6 Happy-Eyeballs fix: disable autoSelectFamily + prefer IPv4.
// npm 9's undici passes autoSelectFamily only as an explicit boolean; by
// default it is undefined, so net.connect() falls back to the process default
// set here. Disabling ASF makes Node connect over IPv4 immediately instead of
// hanging on unreachable IPv6 (AAAA) addresses under WSL's NAT DNS.
// dns.setDefaultResultOrder("ipv4first") additionally sorts DNS results so
// A records are tried before AAAA, avoiding a dead-end IPv6 attempt even when
// the resolver returns IPv6 first.
const net = require("net");
const dns = require("node:dns");
if (typeof net.setDefaultAutoSelectFamily === "function") {
  net.setDefaultAutoSelectFamily(false);
}
if (typeof dns.setDefaultResultOrder === "function") {
  dns.setDefaultResultOrder("ipv4first");
}