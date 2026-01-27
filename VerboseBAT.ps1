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
        } catch {

        }
    }

    if ($rateValue -gt 0) {
        return ([math]::Round($rateValue / 1000, 2)).ToString() + " W ($source)"
    } else {
        return "N/A (Unreliable Data)"
    }
}

while ($true) {
    $battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
    $battInfo = Get-WmiObject -Namespace "root\wmi" -Class "BatteryStatus" -ErrorAction SilentlyContinue
    $fullChargeObj = Get-WmiObject -Namespace "root\wmi" -Class "BatteryFullChargedCapacity" -ErrorAction SilentlyContinue
    $staticData = Get-WmiObject -Namespace "root\wmi" -Class "BatteryStaticData" -ErrorAction SilentlyContinue

    if (-not $battInfo -or -not $fullChargeObj -or -not $staticData) {
        Write-Host "Battery WMI data not fully available. Please check battery status."
        Start-Sleep -Seconds 5
        continue
    }

    $batteryPercent = $battery.EstimatedChargeRemaining
    $fullCharge = $fullChargeObj.FullChargedCapacity
    $designCap = $staticData.DesignedCapacity
    $batteryHealth = 0
    if ($designCap -gt 0) {
        $batteryHealth = [math]::Round(($fullCharge * 100) / $designCap, 1)
    }

    $voltage = "N/A"
    if ($battInfo.Voltage -gt 0) {
        $voltage = ([math]::Round($battInfo.Voltage / 1000, 2)).ToString() + " V"
    }

    if ($battInfo.PowerOnline) {
        $watts = Get-BatteryRate -RateType "Charge"
        Write-Host "Status: Charging | Charging Rate: $watts | Voltage: $voltage | Battery: $batteryPercent% 
Design Capacity: $([math]::Round($designCap / 1000, 2)) Wh | Current Charge Capacity: $([math]::Round($fullCharge / 1000, 2)) Wh | Health: $batteryHealth%"
    } else {
        $watts = Get-BatteryRate -RateType "Discharge"
        Write-Host "Status: On Battery | Discharging Rate: $watts | Voltage: $voltage | Battery: $batteryPercent% 
Design Capacity: $([math]::Round($designCap / 1000, 2)) Wh | Current Charge Capacity: $([math]::Round($fullCharge / 1000, 2)) Wh | Health: $batteryHealth%"
    }

    Start-Sleep -Seconds 5
}
