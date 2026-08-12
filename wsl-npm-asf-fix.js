// WSL npm IPv6 Happy-Eyeballs fix: disable autoSelectFamily globally.
// npm 9's undici passes autoSelectFamily only as an explicit boolean; by
// default it is undefined, so net.connect() falls back to the process default
// set here. Disabling ASF makes Node connect over IPv4 immediately instead of
// hanging on unreachable IPv6 (AAAA) addresses under WSL's NAT DNS.
const net = require("net");
if (typeof net.setDefaultAutoSelectFamily === "function") {
  net.setDefaultAutoSelectFamily(false);
}