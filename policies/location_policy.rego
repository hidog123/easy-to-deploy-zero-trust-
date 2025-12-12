package zta.abac

default allow := false

allow if {
    input.identity.authenticated == true
    input.device.compliant == true
    allowed_location
}

allowed_location if {
    input.context.geolocation == "US"
}

allowed_location if {
    input.context.geolocation == "FR"
}

allowed_location if {
    input.context.geolocation == "UK"
}