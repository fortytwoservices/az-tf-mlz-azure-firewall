# Firewall policy

One firewall policy (`Microsoft.Network/firewallPolicies`): the tier, threat intelligence, DNS, SNAT, SQL
redirect, explicit proxy and insights settings, and for Premium intrusion detection and TLS inspection.
Rules are not in the policy: they are rule collection groups, `modules/rule_collection_group`, whose
`lock_dependency` outputs the caller passes in this module's `lock_dependencies`, so that the policy's
lock is removed around changes to them. A lock on a policy whose rules another Terraform state manages
blocks that state from deleting them.

Every setting is sent, empty when unset, so that removing one reaches Azure. Lock and role assignments come
from [`az-tf-mlz-interfaces`](https://github.com/fortytwoservices/az-tf-mlz-interfaces).
