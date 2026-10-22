# Witchwood

---

## Introduction

Witchwood is a permission schema and evaluation engine for AWS IAM-like policies. Resources are defined on a per-service namespace, supporting nested resources with groups and UUIDv4 identifiers. Policies are defined as a collection of actions, on a collection of resources, for a specific context, with an ALLOW or DENY effect.

Witchwood-C is a C rewrite of the [proof-of-concept Java implementation](https://github.com/Jasmine-Software-Solutions/witchwood). I chose to implement Witchwood in C to extract as much performance as possible at compilation and evaluation time.

Witchwood's primary goal is to provide an evaluation engine for flexible authorization policies with incredibly fast throughput.

## Example

Principal-Assigned Policy:
```json
{
  "effect": "ALLOW",
  "actions": [
    "service.app:DeleteUser"
  ],
  "resources": [
    "service.app://user:*"
  ],
  "condition": {
    "!in": ["protected", { "var": "resource.tags" }]
  }
}
```

*This policy will allow users that it is assigned to to delete users that are not protected.*

## Performance

The C implementation is not yet complete, so there are no performance numbers. However, the Java implementation was able to achieve the following performance:

| Principals | Mode  | Unit  | Throughput    |
|------------| ----- | ----- | ------------- |
| 10,000     | thrpt | ops/s | 12,004,364.38 |
| 100,000    | thrpt | ops/s | 4,556,229.05  |
| 1,000,000  | thrpt | ops/s | 2,165,987.22  |

*Evaluated on a MacBook Air M3 using 1 CPU core*

Witchwood is designed to be highly concurrent, allowing for a single policy to be evaluated concurrently by multiple threads.

### Benchmark Caveat

These performance numbers are not representative of real-world performance because they were evaluated using dummy data. Witchwood has not been deployed on a large enough scale to collect realistic permission graphs. The dummy data was seeded using the following parameters: 10,000 definite resource patterns (explicitly defined in policies), 5 roles per principal, 10 services, 20 actions per service, 30 statements per role, 5 actions per statement, 2 resource patterns per statement, 2 operations per condition, 10 variables per evaluation, 3 nodes per resource pattern, 6 resource groups per service, and an allow-to-deny ratio of 9:1.
## Theory

Witchwood is based on the theory that permissions can be represented in memory with a lot of optimizations, and then evaluated incredibly quickly thanks to modern compute. This means that every time Witchwood is notified a principal becomes active, its entire permission graph is loaded into memory. The Java implementation of Witchwood could load 1 million principals on about 6 gigabytes of memory, and I am expecting significantly more memory efficiency from this C implementation.

## Availability

Witchwood is planned to be highly available, allowing vertical scaling by sharding based on principal and service. This would reduce the memory footprint of policy snapshot to be reasonable per node with many active principals (1 million +).

## Schema

### Services

Services should be represented in Witchwood using fully qualified domain names. For example, if Witchwood was being used for AWS S3 policy evaluation, the service would be `s3.amazonaws.com`.

### Actions

Actions are strings separated by a colon, with the namespace on the left and name on the right. For example, if you have a service qualified `todosumo.app`, and actions `CreateTodo` and `DeleteTodo`, then the fully-qualified action strings would be `todosumo.app:CreateTodo` and `todosumo.app:DeleteTodo`.

### Resources

Resources are URIs with the service as the method, and a series of paths, forward slash separated, with each node being either the wildcard `*`, the greedy wildcard `**`, or an identifier with a group identifier separated by a colon. For example, a bucket in S3 may be represented as `s3.amazonaws.com://account:*/bucket:c996aee8-3aa1-4396-998f-8f075a0a80f2`.

It is important to note a few things. In patterns, the service may be `*`, which means that any resource with the same path will be accepted. `*` may also be provided as the resource group, which means any resource of any group with the same UUID will be accepted. 

Lastly, wildcards are evaluated differently in Witchwood. If a pattern contains a `*`, then it must match one node. If a pattern contains `**`, then it must match at least one node. If you are attempting to create a policy for any resource (e.g, any resource under a specific account), then it is important to define it at both the root level (e.g., `s3.amazonaws.com://account:c1afa730-9478-4382-b155-a0c6fcb12788`) and its children (e.g., `s3.amazonaws.com://account:c1afa730-9478-4382-b155-a0c6fcb12788/**`).

### Conditions

Conditions are evaluated using [JSONLogic](https://jsonlogic.com/). Attributes are provided by the evaluating service, with the following injected at every evaluation by Witchwood:
- The time, at evaluation, keyed `current_time`, in epoch milliseconds
- The evaluating service, keyed `caller`
- The evaluated principal, keyed `principal`

The following operators are supported:
- `==`
- `!=`
- `>`
- `<`
- `>=`
- `<=`
- `in`
- `!in`
- `and`
- `or`
- `var`

## Legal

Witchwood-C is licensed under the [MIT license](LICENSE).