package zta.abac

default allow = false

allow {
    input.identity.authenticated == true
    input.device.compliant == true
    allowed_location
}

allowed_location {
    input.context.geolocation == "FR"
}

allowed_location {
    input.context.geolocation == "US"
}
