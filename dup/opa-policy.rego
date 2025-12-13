package kafka.authz

import future.keywords.if

default allow := false

# Allow rules
allow if {
    # Get the user from the JWT
    user := input.session.sanitizedUser
    
    # Define access matrix
    access_matrix := {
        "admin": {
            "operations": ["Read", "Write", "Create", "Delete", "Alter", "Describe", "ClusterAction"],
            "resources": ["Topic", "Group", "Cluster", "TransactionalId"]
        },
        "kafka-broker": {
            "operations": ["ClusterAction", "Describe"],
            "resources": ["Cluster"]
        },
        "test-producer": {
            "operations": ["Write", "Describe"],
            "resources": ["Topic"],
            "topics": ["secure-data", "audit-logs"]
        },
        "test-consumer": {
            "operations": ["Read", "Describe"],
            "resources": ["Topic", "Group"],
            "topics": ["secure-data"]
        },
        "kafka-ui": {
            "operations": ["Read", "Describe"],
            "resources": ["Topic", "Group", "Cluster"]
        }
    }
    
    # Check if user exists in matrix
    user_rules := access_matrix[user]
    
    # Check operation
    input.operation.name in user_rules.operations
    
    # Check resource type
    input.resource.resourceType.name in user_rules.resources
    
    # Check specific topics if specified
    not user_rules.topics  # No topic restrictions
    or user_rules.topics[_] == input.resource.name
}
