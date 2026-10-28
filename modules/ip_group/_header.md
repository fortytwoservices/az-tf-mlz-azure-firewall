# IP group

One IP group (`Microsoft.Network/ipGroups`): a named set of IP addresses, CIDR prefixes and ranges that
firewall policy rules use as sources and destinations. The root module creates the ones in its
`ip_groups` input and resolves their keys in rules; a separate rules state can call this submodule on its
own. Lock and role assignments come from
[`az-tf-mlz-interfaces`](https://github.com/fortytwoservices/az-tf-mlz-interfaces). A `ReadOnly` lock also
blocks changes to the group's addresses, which do not remove it (removing it on every change would undo
the lock): set `lock = null`, apply your change, then lock it again.
