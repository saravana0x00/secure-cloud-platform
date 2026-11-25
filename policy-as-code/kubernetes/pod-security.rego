package main

import rego.v1

# Every rule below applies only to Pod manifests.

deny contains msg if {
	input.kind == "Pod"
	some c in input.spec.containers
	c.securityContext.privileged == true
	msg := sprintf("Pod %s: container %s must not run privileged", [input.metadata.name, c.name])
}

deny contains msg if {
	input.kind == "Pod"
	some c in input.spec.containers
	not c.securityContext.allowPrivilegeEscalation == false
	msg := sprintf("Pod %s: container %s must set allowPrivilegeEscalation=false", [input.metadata.name, c.name])
}

deny contains msg if {
	input.kind == "Pod"
	some c in input.spec.containers
	not runs_as_non_root(c)
	msg := sprintf("Pod %s: container %s must set runAsNonRoot=true", [input.metadata.name, c.name])
}

deny contains msg if {
	input.kind == "Pod"
	some c in input.spec.containers
	not drops_all_capabilities(c)
	msg := sprintf("Pod %s: container %s must drop ALL capabilities", [input.metadata.name, c.name])
}

deny contains msg if {
	input.kind == "Pod"
	some c in input.spec.containers
	not c.resources.limits.memory
	msg := sprintf("Pod %s: container %s must set a memory limit", [input.metadata.name, c.name])
}

deny contains msg if {
	input.kind == "Pod"
	some c in input.spec.containers
	unpinned_image(c.image)
	msg := sprintf("Pod %s: container %s must use a pinned image tag, not latest or untagged", [input.metadata.name, c.name])
}

# runAsNonRoot may be set on the container or for the whole pod
runs_as_non_root(c) if c.securityContext.runAsNonRoot == true

runs_as_non_root(_) if input.spec.securityContext.runAsNonRoot == true

unpinned_image(image) if endswith(image, ":latest")

unpinned_image(image) if not contains(image, ":")

drops_all_capabilities(c) if "ALL" in c.securityContext.capabilities.drop