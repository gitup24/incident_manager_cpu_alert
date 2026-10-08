# ===== Surveillance CPU en continu (Ubuntu) =====
$Seuil               = 15     # % de charge CPU
$Intervalle          = 5      # secondes entre deux mesures
$MesuresConsecutives = 3      # mesures successives au-dessus du seuil avant alerte
$PauseApresAlerte    = 900    # secondes mini entre deux mails (anti-spam)

$From        = "myMail@gmail.com"
$To          = "myMaile@gmail.com"
#$AppPassword = $env:GMAIL_APP_PASSWORD   # mot de passe d'application Gmail
$AppPassword = "password"

function Get-CpuStat {
    $l = (Get-Content /proc/stat -TotalCount 1) -split '\s+'
    #Get-Counter for Windows
    $v = $l[1..8] | ForEach-Object { [double]$_ }
    [pscustomobject]@{
        Idle  = $v[3] + $v[4]                          # idle + iowait
        Total = ($v | Measure-Object -Sum).Sum
    }
}

function Send-Alert($cpu) {
    try {
        $smtp = [System.Net.Mail.SmtpClient]::new("smtp.gmail.com", 587)
        $smtp.EnableSsl   = $true
        $smtp.Credentials = [System.Net.NetworkCredential]::new($From, $AppPassword)
        $smtp.Send($From, $To,
                "Alerte CPU sur $(hostname) : $cpu %",
                "Charge CPU à $cpu % (seuil : $Seuil %) le $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss').")
        Write-Host "Mail d'alerte envoyé."
    } catch {
        Write-Warning "Échec de l'envoi du mail : $_"
    }
}

$prev      = Get-CpuStat
$compteur  = 0
$derniere  = [datetime]::MinValue

while ($true) {
    Start-Sleep -Seconds $Intervalle
    $cur    = Get-CpuStat
    $dTotal = $cur.Total - $prev.Total
    $dIdle  = $cur.Idle  - $prev.Idle
    $prev   = $cur
    if ($dTotal -le 0) { continue }

    $cpu = [math]::Round(100 * (1 - $dIdle / $dTotal), 1)
    Write-Host "$(Get-Date -Format 'HH:mm:ss')  CPU : $cpu %"

    if ($cpu -ge $Seuil) { $compteur++ } else { $compteur = 0 }

    if ($compteur -ge $MesuresConsecutives -and
            ((Get-Date) - $derniere).TotalSeconds -ge $PauseApresAlerte) {
        Send-Alert $cpu
        $derniere = Get-Date
    }
}