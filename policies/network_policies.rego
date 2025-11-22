package zta.network

import future.keywords.in

# Network segmentation policies
default allow_network_access = false

allow_network_access {
    # Micro-segmentation based on identity
    input.identity.department == "engineering"
    input.resource.network_segment == "dev-environment"
}

allow_network_access {
    input.identity.department == "finance"
    input.resource.network_segment == "financial-systems"
}

allow_network_access {
    input.identity.role == "admin"
    input.resource.network_segment == "admin-network"
}

# Logical segmentation rules
network_segment = "dev-environment" {
    input.resource.tags.environment == "development"
}

network_segment = "production" {
    input.resource.tags.environment == "production"
}

network_segment = "financial-systems" {
    input.resource.tags.criticality == "high"
    input.resource.tags.department == "finance"
}

# Cross-segment communication rules
allow_cross_segment = false

allow_cross_segment {
    input.source.segment == "dev-environment"
    input.destination.segment == "staging"
    input.purpose == "deployment"
}

allow_cross_segment {
    input.source.segment == "admin-network"
    # Admins can access all segments
}
