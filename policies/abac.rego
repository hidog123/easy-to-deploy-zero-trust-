package zta.abac
default allow = false
allow {
    input.identity.authenticated == true
    input.device.compliant == true
}
