package zta.abac

default allow := false

allow if {
    input.identity.authenticated == true
    input.device.compliant == true
}