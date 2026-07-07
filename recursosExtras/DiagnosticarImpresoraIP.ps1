# =====================================================================================
# SCRIPT DE DIAGNOSTICO DE IMPRESORAS DE RED VIA SNMP
# =====================================================================================
# Este script es 100% independiente y NO afecta a los archivos del proyecto ShellSW.
# Funciona a través de consultas SNMP directas (Puerto UDP 161) sin requerir Active Directory.
# Compatible desde Windows 7 y PowerShell 2.0 en adelante.
# =====================================================================================

Clear-Host
Write-Host "======================================================================" -ForegroundColor White
Write-Host "      DIAGNOSTICO DE IMPRESORA DE RED INDEPENDIENTE (VÍA SNMP)" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor White

# 1. Solicitar la dirección IP de la Impresora
$printerIP = Read-Host "Ingrese la direccion IP de la impresora a diagnosticar (ej. 192.168.176.50)"
if ($printerIP -eq "") {
    Write-Host "Operacion cancelada." -ForegroundColor Yellow
    Exit
}

# Comprobar conectividad básica por Ping
Write-Host "`nVerificando conectividad IP (Ping)..." -ForegroundColor Cyan
if (Test-Connection -ComputerName $printerIP -Count 2 -Quiet) {
    Write-Host "[OK] La impresora responde a Ping." -ForegroundColor Green
} else {
    Write-Host "[ADVERTENCIA] No hay respuesta a Ping. Intentando consulta SNMP de todos modos..." -ForegroundColor Yellow
}

# =====================================================================================
# FUNCIONES AUXILIARES SNMP (Decodificación ASN.1 / BER NATIVA)
# =====================================================================================

function Convert-OidToBytes ($oidString) {
    $parts = $oidString.Split('.') | ForEach-Object { [int]$_ }
    $bytes = [System.Collections.Generic.List[byte]]::new()
    $bytes.Add([byte](40 * $parts[0] + $parts[1]))
    for ($i = 2; $i -lt $parts.Count; $i++) {
        $val = $parts[$i]
        $temp = [System.Collections.Generic.List[byte]]::new()
        $temp.Add([byte]($val -band 0x7f))
        $val = $val -shr 7
        while ($val -gt 0) {
            $temp.Insert(0, [byte](($val -band 0x7f) -bor 0x80))
            $val = $val -shr 7
        }
        $bytes.AddRange($temp)
    }
    return $bytes.ToArray()
}

function Build-SnmpGetPacket ($community, $oidString) {
    $oidBytes = Convert-OidToBytes $oidString
    
    # Varbind: Sequence de [OID, Null]
    $varbind = [System.Collections.Generic.List[byte]]::new()
    $varbind.Add(0x06) # OID Tag
    $varbind.Add([byte]$oidBytes.Length)
    $varbind.AddRange($oidBytes)
    $varbind.Add(0x05) # Null Value Tag
    $varbind.Add(0x00)
    
    # Varbind List: Sequence de Varbind
    $varbindList = [System.Collections.Generic.List[byte]]::new()
    $varbindList.Add(0x30)
    $varbindList.Add([byte]$varbind.Count)
    $varbindList.AddRange($varbind)
    
    # GetRequest PDU
    $pdu = [System.Collections.Generic.List[byte]]::new()
    $pdu.Add(0x02) # RequestID
    $pdu.Add(0x04)
    $pdu.AddRange(@(0x00, 0x00, 0x00, 0x01))
    $pdu.Add(0x02) # ErrorStatus
    $pdu.Add(0x01)
    $pdu.Add(0x00)
    $pdu.Add(0x02) # ErrorIndex
    $pdu.Add(0x01)
    $pdu.Add(0x00)
    $pdu.AddRange($varbindList)
    
    # SNMP Message Wrapper
    $communityBytes = [System.Text.Encoding]::ASCII.GetBytes($community)
    
    $message = [System.Collections.Generic.List[byte]]::new()
    $message.Add(0x02) # Version Tag
    $message.Add(0x01)
    $message.Add(0x01) # SNMP v2c (valor 1)
    $message.Add(0x04) # Community Tag
    $message.Add([byte]$communityBytes.Length)
    $message.AddRange($communityBytes)
    
    $pduEnvelope = [System.Collections.Generic.List[byte]]::new()
    $pduEnvelope.Add(0xa0) # GetRequest Tag
    $pduEnvelope.Add([byte]$pdu.Count)
    $pduEnvelope.AddRange($pdu)
    
    $message.AddRange($pduEnvelope)
    
    $packet = [System.Collections.Generic.List[byte]]::new()
    $packet.Add(0x30)
    $packet.Add([byte]$message.Count)
    $packet.AddRange($message)
    
    return $packet.ToArray()
}

function Get-SnmpValue ($ip, $oid, $community = "public") {
    $port = 161
    $socket = New-Object System.Net.Sockets.UdpClient
    $socket.Client.ReceiveTimeout = 2500 # 2.5 segundos de timeout
    
    try {
        $packet = Build-SnmpGetPacket $community $oid
        $socket.Connect($ip, $port)
        $socket.Send($packet, $packet.Length) | Out-Null
        
        $remoteEP = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $response = $socket.Receive([ref]$remoteEP)
        
        # Encontrar el OID en los bytes recibidos para ubicar el valor
        $oidBytes = Convert-OidToBytes $oid
        $oidIndex = -1
        for ($i = 0; $i -le ($response.Length - $oidBytes.Length); $i++) {
            $match = $true
            for ($j = 0; $j -lt $oidBytes.Length; $j++) {
                if ($response[$i + $j] -ne $oidBytes[$j]) {
                    $match = $false
                    break
                }
            }
            if ($match) {
                $oidIndex = $i
                break
            }
        }
        
        if ($oidIndex -eq -1) { return $null }
        
        # El tag de valor empieza inmediatamente después de los bytes de OID
        $valTagIndex = $oidIndex + $oidBytes.Length
        if ($valTagIndex -ge $response.Length) { return $null }
        
        $valueTag = $response[$valTagIndex]
        $lenByte = $response[$valTagIndex + 1]
        $valDataIndex = $valTagIndex + 2
        
        $valueLen = $lenByte
        if ($lenByte -band 0x80) {
            $numLenBytes = $lenByte -band 0x7f
            $valueLen = 0
            for ($k = 0; $k -lt $numLenBytes; $k++) {
                $valueLen = ($valueLen -shl 8) + $response[$valDataIndex + $k]
            }
            $valDataIndex += $numLenBytes
        }
        
        if (($valDataIndex + $valueLen) -gt $response.Length) { return $null }
        
        # Decodificar el tipo
        if ($valueTag -eq 0x04) {
            # Cadena de texto ASCII
            return [System.Text.Encoding]::ASCII.GetString($response, $valDataIndex, $valueLen)
        } elseif ($valueTag -eq 0x02 -or $valueTag -eq 0x41 -or $valueTag -eq 0x42 -or $valueTag -eq 0x43) {
            # Números Enteros
            $val = 0
            for ($k = 0; $k -lt $valueLen; $k++) {
                $val = ($val -shl 8) + $response[$valDataIndex + $k]
            }
            return $val
        } else {
            return $null
        }
    } catch {
        return $null
    } finally {
        $socket.Close()
    }
}

# =====================================================================================
# EJECUCIÓN DEL DIAGNÓSTICO
# =====================================================================================

Write-Host "Enviando consultas SNMP a la impresora en $printerIP..." -ForegroundColor Cyan

# 1. Consultar sysDescr (Modelo y Fabricante)
$sysDescr = Get-SnmpValue $printerIP "1.3.6.1.2.1.1.1.0"
if ($sysDescr -eq $null) {
    Write-Host "`n[ERROR]: La impresora no responde a consultas SNMP en el puerto 161." -ForegroundColor Red
    Write-Host "Verifique lo siguiente:" -ForegroundColor Gray
    Write-Host "  1. Que la direccion IP ($printerIP) sea correcta." -ForegroundColor Gray
    Write-Host "  2. Que la impresora este encendida y conectada a la red." -ForegroundColor Gray
    Write-Host "  3. Que el servicio SNMP este HABILITADO en la configuracion de la impresora." -ForegroundColor Gray
    Write-Host "  4. Que la comunidad SNMP sea 'public' (por defecto en la mayoria de dispositivos)." -ForegroundColor Gray
    Exit
}

# 2. Consultar nombre de host (sysName)
$sysName = Get-SnmpValue $printerIP "1.3.6.1.2.1.1.5.0"

# 3. Consultar tipo de IP (Configuración de arranque HP JetDirect/Estándar)
# 1 = DHCP, 2 = BootP, 3 = Manual/Static
$ipTypeVal = Get-SnmpValue $printerIP "1.3.6.1.4.1.11.2.4.3.5.1.1.1.0"
$ipType = "Desconocido / No reportado"
if ($ipTypeVal -ne $null) {
    if ($ipTypeVal -eq 1) { $ipType = "DINAMICA (DHCP)" }
    elseif ($ipTypeVal -eq 2) { $ipType = "DINAMICA (BootP)" }
    elseif ($ipTypeVal -eq 3) { $ipType = "FIJA (ESTATICA / MANUAL)" }
}

# 4. Consultar Estado Físico (hrPrinterStatus)
# 1=other, 2=unknown, 3=idle, 4=printing, 5=warmup
$statusVal = Get-SnmpValue $printerIP "1.3.6.1.2.1.25.3.5.1.1.1"
$status = "Desconocido"
if ($statusVal -ne $null) {
    switch ($statusVal) {
        1 { $status = "Otro (No especificado)" }
        2 { $status = "Desconocido" }
        3 { $status = "Listo / En Espera (Idle)" }
        4 { $status = "Imprimiendo (Printing)" }
        5 { $status = "Calentando (Warmup)" }
    }
}

# 5. Consultar Contador Total de Páginas (prtMarkerLifeCount)
$pages = Get-SnmpValue $printerIP "1.3.6.1.2.1.43.10.2.1.4.1.1"
$pagesInfo = if ($pages -ne $null) { "$pages paginas" } else { "No disponible" }

# 6. Consultar Tamaño de Hojas Configurado en Bandeja 1 (prtInputMediaName)
# OIDs comunes: Bandeja 1: .1.12.1.1 , Bandeja 2: .1.12.1.2
$paperSize = Get-SnmpValue $printerIP "1.3.6.1.2.1.43.13.1.1.12.1.1"
if ($paperSize -eq $null) {
    $paperSize = Get-SnmpValue $printerIP "1.3.6.1.2.1.43.13.1.1.12.1.2"
}
$paperSizeInfo = if ($paperSize -ne $null) { $paperSize.Trim() } else { "Carta / A4 (Por defecto)" }

# 7. Consultar Nivel de Tóner/Tinta (prtMarkerSuppliesLevel / Capacity)
$tonerDesc = Get-SnmpValue $printerIP "1.3.6.1.2.1.43.11.1.1.6.1.1"
$tonerCur = Get-SnmpValue $printerIP "1.3.6.1.2.1.43.11.1.1.9.1.1"
$tonerMax = Get-SnmpValue $printerIP "1.3.6.1.2.1.43.11.1.1.8.1.1"

$tonerPct = "No disponible"
if ($tonerCur -ne $null -and $tonerMax -ne $null -and $tonerMax -gt 0) {
    if ($tonerCur -lt 0) {
        $tonerPct = "Nivel bajo / OK (Reporte no lineal)"
    } else {
        $pct = [Math]::Round(($tonerCur / $tonerMax) * 100, 1)
        $tonerPct = "$pct%"
    }
}

# =====================================================================================
# IMPRIMIR REPORTE FINAL
# =====================================================================================
Write-Host "`n======================================================================" -ForegroundColor White
Write-Host "          DATOS DE DIAGNOSTICO DE IMPRESORA EN RED" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor White
Write-Host " Direccion IP:        $printerIP"
Write-Host " Asignacion de IP:    $ipType" -ForegroundColor Cyan
Write-Host " Nombre Hostname:     $sysName"
Write-Host " Fabricante/Modelo:   $($sysDescr.Trim())" -ForegroundColor Yellow
Write-Host " Estado Actual:       $status" -ForegroundColor Green
Write-Host " Contador de Hojas:   $pagesInfo"
Write-Host " Tamaño de Papel:     $paperSizeInfo"
if ($tonerDesc) {
    Write-Host " Suministro principal: $($tonerDesc.Trim()) (Nivel: $tonerPct)" -ForegroundColor Cyan
} else {
    Write-Host " Nivel de Suministros: $tonerPct" -ForegroundColor Cyan
}
Write-Host "======================================================================`n" -ForegroundColor White

Read-Host "Presione Enter para finalizar el script independiente..."
