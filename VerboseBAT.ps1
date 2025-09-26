function Get-BatteryRate {
    param (
        [string]$RateType
    )

    $battInfo = Get-WmiObject -Namespace "root\wmi" -Class "BatteryStatus" -ErrorAction SilentlyContinue
    if (-not $battInfo) {
        return "N/A (WMI Error)"
    }

    $rateValue = 0
    $source = "WMI"
    if ($RateType -eq "Charge" -and $battInfo.PowerOnline) {
        $rateValue = $battInfo.ChargeRate
    } elseif ($RateType -eq "Discharge" -and -not $battInfo.PowerOnline) {
        $rateValue = $battInfo.DischargeRate
    }

    if ($rateValue -lt 500 -and (($RateType -eq "Charge" -and $battInfo.PowerOnline) -or ($RateType -eq "Discharge" -and -not $battInfo.PowerOnline -and $battInfo.RemainingCapacity -gt 0))) {
        try {
            $perfCounterPath = ""
            if ($RateType -eq "Charge") {
                $perfCounterPath = "\Battery(*)\Charge Rate"
            } elseif ($RateType -eq "Discharge") {
                $perfCounterPath = "\Battery(*)\Discharge Rate"
            }
            $counter = Get-Counter -Counter $perfCounterPath -ErrorAction SilentlyContinue
            if ($counter) {
                $newRate = $counter.CounterSamples | Select-Object -ExpandProperty CookedValue
                if ($newRate -gt 500) {
                    $rateValue = $newRate
                    $source = "Perf Counter"
                }
            }
        } catch { }
    }

    if ($rateValue -gt 0) {
        return ([math]::Round($rateValue / 1000, 2)).ToString() + " W ($source)"
    } else {
        return "N/A (Unreliable Data)"
    }
}

while ($true) {
    $battInfo = Get-WmiObject -Namespace "root\wmi" -Class "BatteryStatus" -ErrorAction SilentlyContinue
    if (-not $battInfo) {
        Write-Host "Battery WMI data not available."
        Start-Sleep -Seconds 5
        continue
    }

    if ($battInfo.PowerOnline) {
        $rate = Get-BatteryRate -RateType "Charge"
        Write-Host "Charging Rate: $rate"
    } else {
        $rate = Get-BatteryRate -RateType "Discharge"
        Write-Host "Discharging Rate: $rate"
    }

    Start-Sleep -Seconds 5
}
