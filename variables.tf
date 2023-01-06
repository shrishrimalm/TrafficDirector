
variable "project_id" {
  type        = string
  description = "The ID of the project in which the resource belongs"
}

/*
variable "project_number" {
  type        = string
  description = "Project number in which the resource belongs"
} 

variable "networks" {
  type        = string
  description = "The network id to which all network endpoints in the NEG belong."
}

variable "region" {
  type        = string
  description = "The GCP region for this subnetwork"
}

variable "zone" {
  type        = string
  description = "Zone where the network endpoint group is located"
}

variable "subnets" {
  type        = string
  description = "subnetwork id to which all network endpoints in the NEG belong"
}

variable "host_name" {
  type        = string
  description = "compute_url_map : The list of host patterns to match in. They must be valid hostnames"
}

variable "aws_network_endpoint_type" {
  description = "Type of network endpoints in this network endpoint group.NON_GCP_PRIVATE_IP_PORT is used for hybrid connectivity network endpoint groups."
  type        = string
  default     = "NON_GCP_PRIVATE_IP_PORT"
}

variable "gcp_network_endpoint_type" {
  description = "Type of network endpoints in this network endpoint group.Default value is GCE_VM_IP_PORT. Possible values are GCE_VM_IP, GCE_VM_IP_PORT"
  type        = string
  default     = "GCE_VM_IP_PORT"
}

variable "aws_resource_name_prefix" {
  description = "The prefix to apply to resource names"
  type        = string
  default     = "aws"
}

variable "gcp_resource_name_prefix" {
  description = "The prefix to apply to resource names"
  type        = string
  default     = "gcp"
}

variable "aws_endpoint_ip" {
  description = "IPv4 address of aws network endpoint. The IP address must belong to a VM in GCE (either the primary IP or as part of an aliased IP range)."
  type        = string
}

variable "load_balancing_schemes" {
  description = "This signifies what the GlobalForwardingRule will be used for. The value of INTERNAL_SELF_MANAGED means that this will be used for Internal Global HTTP(S) LB."
  type        = string
  default     = "INTERNAL_SELF_MANAGED"
}

variable "load_balancing_policy" {
  description = "The load balancing algorithm used within the scope of the locality."
  type        = string
  default     = "ROUND_ROBIN"
}

variable "ports" {
  description = "Port number for the health check request."
  type        = string
  default     = "80"
}

variable "awsneg_ports" {
  description = "Port number of aws network endpoint group."
  type        = string
  default     = "90"
}

variable "gcpneg_ports" {
  description = "Port number of gcp network endpoint group."
  type        = string
  default     = "90"
}

variable "route_priority" {
  description = "For routeRules within a given pathMatcher, priority determines the order in which load balancer will interpret routeRules. RouteRules are evaluated in order of priority, from the lowest to highest number. The priority of a rule decreases as its number increases (1, 2, 3, N+1)."
  type        = number
  default     = 1
}

variable "aws_weight" {
  description = "The weights determine the fraction of traffic that flows to aws backend service."
  type        = number
}


variable "gcp_weight" {
  description = "The weights determine the fraction of traffic that flows to gcp backend service."
  type        = number
}

variable "awsfwrule_ip" {
  description = "The IP address that this forwarding rule serves. When a client sends traffic to this IP address, the forwarding rule directs the traffic to the target that you specify in the forwarding rule. The loadBalancingScheme and the forwarding rule's target determine the type of IP address that you can use."
  type        = string
}

variable "gcpfwrule_ip" {
  description = "The IP address that this forwarding rule serves. When a client sends traffic to this IP address, the forwarding rule directs the traffic to the target that you specify in the forwarding rule. The loadBalancingScheme and the forwarding rule's target determine the type of IP address that you can use."
  type        = string
}

variable "max_rate_per_endpoint_compute" {
  description = "The max requests per second (RPS) that a single backend network endpoint can handle. This is used to calculate the capacity of the group."
  type        = number
  default     = 10
}*/