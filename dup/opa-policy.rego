package kafka.authz

default allow = false

# Allow everything that is not explicitly denied
allow {
  not deny
}

# Deny block
deny {
  is_read_operation
  track_topic
  not consumer_is_whitelisted_for_foo
}

# Format: "easy_to_read_client_name": {"client_name_in_keycloak"}
consumer_whitelist = {
  "test_consumer": {"test_consumer"},
}

topic_metadata = {
  "foo": {"tags": ["foo"]},
  "bar": {"tags": ["bar"]},
}

#-----------------------------------
# Helpers for checking topic access.
#-----------------------------------

foo_topic {
  topic_metadata[topic_name].tags[_] == "foo"
}

bar_topic {
  topic_metadata[topic_name].tags[_] == "bar"
}

# Grant the 'test_consumer' user access to read from the 'foo' topic
consumer_is_whitelisted_for_foo {
  consumer_whitelist.test_consumer[_] == principal.name
}

# Helpers for processing Kafka operation input.
is_read_operation {
  input.operation.name == "Read"
}

is_write_operation {
  input.operation.name == "Write"
}

is_topic_resource {
  input.resource.resourceType.name == "Topic"
}

topic_name = input.resource.name {
  is_topic_resource
}

track_topic {
  topic_name == "foo"
}

# This is where we grab the name of the user that was set when creating the JWT for the authenticated user
principal = {"name": name} {
  name := input.session.sanitizedUser
}
