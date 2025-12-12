Write-Host " Testing Zero Trust Policy Engine" -ForegroundColor Cyan

$tests = @(
    @{
        Name = "Unauthenticated User"
        Input = @{
            identity = @{ authenticated = $false }
            device = @{ compliant = $true }
        }
        ExpectedResult = $false
        Description = "Should DENY - not authenticated"
    },
    @{
        Name = "Non-Compliant Device"
        Input = @{
            identity = @{ authenticated = $true }
            device = @{ compliant = $false }
        }
        ExpectedResult = $false
        Description = "Should DENY - device not compliant"
    },
    @{
        Name = "Valid Access"
        Input = @{
            identity = @{ authenticated = $true }
            device = @{ compliant = $true }
        }
        ExpectedResult = $true
        Description = "Should ALLOW - authenticated + compliant"
    },
    @{
        Name = "No Authentication"
        Input = @{
            identity = @{ authenticated = $false }
            device = @{ compliant = $false }
        }
        ExpectedResult = $false
        Description = "Should DENY - no auth, no compliance"
    }
)

$passed = 0
$failed = 0

foreach ($test in $tests) {
    Write-Host "`n[$($test.Name)]" -ForegroundColor Yellow
    Write-Host "  $($test.Description)" -ForegroundColor Gray
    
    $body = @{ input = $test.Input } | ConvertTo-Json -Depth 10
    
    try {
        $result = Invoke-RestMethod -Uri "http://localhost:8181/v1/data/zta/abac/allow" `
            -Method POST -Body $body -ContentType "application/json"
        
        if ($result.result -eq $test.ExpectedResult) {
            Write-Host "   PASS" -ForegroundColor Green
            Write-Host "     Expected: $($test.ExpectedResult), Got: $($result.result)" -ForegroundColor Gray
            $passed++
        } else {
            Write-Host "   FAIL" -ForegroundColor Red
            Write-Host "     Expected: $($test.ExpectedResult), Got: $($result.result)" -ForegroundColor Gray
            $failed++
        }
    } catch {
        Write-Host "   ERROR: $_" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`n" -NoNewline
Write-Host "" * 60 -ForegroundColor Cyan
Write-Host " Test Summary" -ForegroundColor Cyan
Write-Host "" * 60 -ForegroundColor Cyan
Write-Host "  Passed: " -NoNewline; Write-Host "$passed" -ForegroundColor Green
Write-Host "  Failed: " -NoNewline; Write-Host "$failed" -ForegroundColor $(if($failed -eq 0){'Green'}else{'Red'})
Write-Host "  Total:  $($tests.Count)" -ForegroundColor Gray

if ($failed -eq 0) {
    Write-Host "`n All tests passed! Zero Trust policies are working correctly." -ForegroundColor Green
} else {
    Write-Host "`n  Some tests failed. Check OPA configuration." -ForegroundColor Yellow
}
