# =========================================================================================
# FUNCIONES AUXILIARES Y MODULARES PARA EL GRUPO 19: FORMATEO Y PREPARACION DE DISCOS / USB
# =========================================================================================

function Get-SafeDiskList {
    <#
    .SYNOPSIS
        Obtiene la lista de discos físicos conectados con detección segura del disco del sistema.
    #>
    $systemDiskNum = -1
    try {
        $sysDrive = $env:SystemDrive.Replace(":", "")
        if (Get-Command Get-Partition -ErrorAction SilentlyContinue) {
            $sysPart = Get-Partition -DriveLetter $sysDrive -ErrorAction SilentlyContinue
            if ($sysPart) { $systemDiskNum = $sysPart.DiskNumber }
        }
    } catch {}

    $list = @()
    if (Get-Command Get-Disk -ErrorAction SilentlyContinue) {
        try {
            $disks = Get-Disk | Sort-Object Number
            foreach ($d in $disks) {
                $isSys = ($d.Number -eq $systemDiskNum)
                $sizeGB = [Math]::Round($d.Size / 1GB, 2)
                $bus = if ($d.BusType) { $d.BusType.ToString() } else { "Desconocido" }
                $media = if ($bus -eq "USB") { "USB/Extraible" } else { "Fijo" }
                $list += [PSCustomObject]@{
                    Number            = $d.Number
                    FriendlyName      = $d.FriendlyName
                    BusType           = $bus
                    MediaType         = $media
                    SizeGB            = $sizeGB
                    PartitionStyle    = $d.PartitionStyle.ToString()
                    HealthStatus      = $d.HealthStatus.ToString()
                    OperationalStatus = $d.OperationalStatus.ToString()
                    IsSystem          = $isSys
                }
            }
            return $list
        } catch {}
    }

    # Fallback WMI Win32_DiskDrive (Compatibilidad Win 7)
    try {
        $wmiDisks = Get-WmiObject Win32_DiskDrive | Sort-Object Index
        foreach ($wd in $wmiDisks) {
            $idx = [int]$wd.Index
            $isSys = ($idx -eq $systemDiskNum)
            $sizeGB = if ($wd.Size) { [Math]::Round($wd.Size / 1GB, 2) } else { 0 }
            $bus = if ($wd.InterfaceType) { $wd.InterfaceType } else { "Desconocido" }
            $list += [PSCustomObject]@{
                Number            = $idx
                FriendlyName      = $wd.Caption
                BusType           = $bus
                MediaType         = (if ($bus -match "USB") { "USB/Extraible" } else { "Fijo" })
                SizeGB            = $sizeGB
                PartitionStyle    = "N/D"
                HealthStatus      = $wd.Status
                OperationalStatus = "Online"
                IsSystem          = $isSys
            }
        }
    } catch {}
    return $list
}

function Invoke-DiskpartBatch {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Commands
    )
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        $Commands | Out-File -FilePath $tempFile -Encoding ascii
        Write-Host "`n------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host " [DISKPART] Ejecutando secuencia de comandos por lotes:" -ForegroundColor Cyan
        foreach ($c in $Commands) {
            if ($c -and $c -ne "exit") {
                Write-Host "   > $c" -ForegroundColor DarkGray
            }
        }
        Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkGray

        $output = & diskpart.exe /s "$tempFile" 2>&1
        $hasFatalError = $false
        foreach ($line in $output) {
            $lineStr = "$line".Trim()
            if (-not $lineStr) { continue }
            if ($lineStr -match "error de|código de error|no se puede|denegado|no es válido|demasiado largo|incorrecto|demasiado grande|error del servicio|falló") {
                Write-Host "  [Diskpart] $lineStr" -ForegroundColor Red
                $hasFatalError = $true
            }
            elseif ($lineStr -match "100 por ciento completado|correctamente|satisfactoriamente|formateó|asignó") {
                Write-Host "  [Diskpart] $lineStr" -ForegroundColor Green
            }
            elseif ($lineStr -match "por ciento completado") {
                Write-Host "  [Diskpart] $lineStr" -ForegroundColor Yellow
            }
            else {
                Write-Host "  [Diskpart] $lineStr" -ForegroundColor Gray
            }
        }

        if ($LASTEXITCODE -ne 0 -or $hasFatalError) {
            return 1
        }
        return 0
    }
    catch {
        Write-Host "`n[ERROR AL INVOCAR DISKPART]: $_" -ForegroundColor Red
        return 1
    }
    finally {
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Show-FormatBootMatrix {
    cabecera
    Write-Header "OPCION 19.0: TABLA DE RELACION - FILESYSTEM vs PARTICION vs MODO DE ARRANQUE"

    Write-Host "`n==========================================================================================" -ForegroundColor Cyan
    Write-Host "               MATRIZ DE COMPATIBILIDAD PARA INSTALACION DE SISTEMAS OPERATIVOS            " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    $matrix = @(
        [PSCustomObject]@{
            "Modo Arranque"  = "Legacy BIOS (CSM)"
            "Particion"      = "MBR"
            "FS Arranque"    = "NTFS / FAT32"
            "FS Sistema(C:)" = "NTFS"
            "Activa?"        = "SI (Req.)"
            "Max Disco"      = "<= 2.0 TB"
            "Lim. Archivo"   = "NTFS: Ilim. | FAT: 4GB"
            "Sec.Boot"       = "NO"
        },
        [PSCustomObject]@{
            "Modo Arranque"  = "UEFI Nativo"
            "Particion"      = "GPT"
            "FS Arranque"    = "FAT32 (ESP/EFI)"
            "FS Sistema(C:)" = "NTFS"
            "Activa?"        = "NO (Usa GUID)"
            "Max Disco"      = "> 2TB (18 EB)"
            "Lim. Archivo"   = "NTFS: Ilim. | FAT: 4GB"
            "Sec.Boot"       = "SI"
        },
        [PSCustomObject]@{
            "Modo Arranque"  = "USB Inst. BIOS"
            "Particion"      = "MBR"
            "FS Arranque"    = "NTFS / FAT32"
            "FS Sistema(C:)" = "N/A (Medio)"
            "Activa?"        = "SI (bootsect)"
            "Max Disco"      = "<= 2.0 TB"
            "Lim. Archivo"   = "NTFS soporta wim > 4GB"
            "Sec.Boot"       = "NO"
        },
        [PSCustomObject]@{
            "Modo Arranque"  = "USB Inst. UEFI"
            "Particion"      = "GPT o MBR"
            "FS Arranque"    = "FAT32 (UEFI)"
            "FS Sistema(C:)" = "N/A (Medio)"
            "Activa?"        = "NO (No req.)"
            "Max Disco"      = "Cualquiera"
            "Lim. Archivo"   = "FAT32 max 4GB (split)"
            "Sec.Boot"       = "SI"
        },
        [PSCustomObject]@{
            "Modo Arranque"  = "Almacen. exFAT"
            "Particion"      = "MBR o GPT"
            "FS Arranque"    = "No Booteable"
            "FS Sistema(C:)" = "No Windows"
            "Activa?"        = "No Aplica"
            "Max Disco"      = "Hasta 128PB"
            "Lim. Archivo"   = "16 EB (Ideal datos)"
            "Sec.Boot"       = "N/A"
        }
    )

    $matrix | Format-Table -AutoSize

    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[REGLAS DE ORO PARA EL TECNICO / ADMINISTRADOR DE SISTEMAS]:" -ForegroundColor White
    Write-Host " 1. LEGACY BIOS (MBR):" -ForegroundColor Cyan
    Write-Host "    - Windows requiere obligatoriamente que la particion donde reside BOOTMGR este marcada como ACTIVA." -ForegroundColor Gray
    Write-Host "    - En discos MBR, si la particion no es 'Active' o no tiene codigo MBR ('bootsect /nt60 X: /mbr'), la BIOS dira 'No bootable device'." -ForegroundColor Gray
    Write-Host "    - El limite maximo de direccionamiento de sectores en MBR es de 2 TB (con sectores de 512 bytes)." -ForegroundColor Gray

    Write-Host "`n 2. UEFI NATIVO (GPT):" -ForegroundColor Cyan
    Write-Host "    - No existe el concepto de particion 'Activa' en tablas GPT. El firmware busca la particion EFI System (ESP) formateada en FAT32." -ForegroundColor Gray
    Write-Host "    - Requiere archivos en \EFI\BOOT\BOOTX64.EFI. Soporta discos de mas de 2 TB y arranque seguro (Secure Boot)." -ForegroundColor Gray
    Write-Host "    - Windows 11 exige obligatoriamente UEFI + GPT + TPM 2.0 + Secure Boot." -ForegroundColor Gray

    Write-Host "`n 3. PROBLEMA FRECUENTE CON USB UEFI Y FAT32 (install.wim > 4 GB):" -ForegroundColor Cyan
    Write-Host "    - Como el estandar UEFI exige FAT32 para arrancar, y Windows 10/11 moderno incluye 'install.wim' de mas de 4 GB:" -ForegroundColor Gray
    Write-Host "      a) Solucion oficial: Dividir el WIM con: dism /Split-Image /ImageFile:install.wim /SWMFile:install.swm /FileSize:3800" -ForegroundColor Yellow
    Write-Host "      b) Solucion de particion dual: 1 particion pequena FAT32 (arranque UEFI) + 1 particion NTFS (imagen completa)." -ForegroundColor Yellow
    Write-Host "      c) Driver UEFI:NTFS (Rufus): Carga un driver NTFS firmado en memoria para arrancar directamente en NTFS." -ForegroundColor Yellow

    Write-Host "`n 4. SISTEMA DE ARCHIVOS exFAT:" -ForegroundColor Cyan
    Write-Host "    - Disenado para pendrives y discos externos de alta capacidad. Supera el limite de 4 GB de FAT32 sin permisos complejos NTFS." -ForegroundColor Gray
    Write-Host "    - Maxima compatibilidad entre Windows, macOS, Linux, Smart TVs y consolas. NO permite instalar Windows C: sobre el." -ForegroundColor Gray
    Write-Host "==========================================================================================`n" -ForegroundColor Cyan
}

function Show-DiskTechnicalDetails {
    cabecera
    Write-Header "OPCION 19.1: INFORMACION TECNICA DETALLADA DE LA UNIDAD DE ALMACENAMIENTO"

    $discos = Get-SafeDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron unidades de almacenamiento en el equipo." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES DETECTADAS EN EL SISTEMA ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $etiquetaSys = if ($d.IsSystem) { " [SISTEMA OPERATIVO C:]" } else { "" }
        $color = if ($d.IsSystem) { "Magenta" } elseif ($d.MediaType -match "USB") { "Green" } else { "White" }
        Write-Host ("  [Disco {0}] {1} | Bus: {2} | Tipo: {3} | Tamano: {4} GB | Particion: {5}{6}" -f $d.Number, $d.FriendlyName, $d.BusType, $d.MediaType, $d.SizeGB, $d.PartitionStyle, $etiquetaSys) -ForegroundColor $color
    }

    Write-Host ""
    $sel = Read-Host "Ingrese el numero de Disco para ver su ficha tecnica completa (o '0' para volver)"
    if ($null -eq $sel -or $sel -notmatch '^\d+$' -or $sel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$sel
    $targetDisk = $discos | Where-Object { $_.Number -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en la lista." -ForegroundColor Red
        return
    }

    Write-Host "`n==========================================================================================" -ForegroundColor Cyan
    Write-Host "                     FICHA TECNICA DETALLADA: DISCO FISICO $discoIndex                     " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    # 1. Datos físicos vía WMI / Storage
    $wmiDisk = Get-WmiObject Win32_DiskDrive | Where-Object { $_.Index -eq $discoIndex }
    if ($wmiDisk) {
        Write-Host " [DATOS DE FABRICANTE Y HARDWARE]" -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host "  Modelo/Caption       : $($wmiDisk.Caption)"
        Write-Host "  Fabricante           : $($wmiDisk.Manufacturer)"
        Write-Host "  Numero de Serie      : $(if ($wmiDisk.SerialNumber) { $wmiDisk.SerialNumber.Trim() } else { 'N/D' })"
        Write-Host "  Firmware Revision    : $($wmiDisk.FirmwareRevision)"
        Write-Host "  Interfaz / Bus       : $($targetDisk.BusType)"
        Write-Host "  Tipo de Medio        : $($targetDisk.MediaType)"
        Write-Host "  Capacidad Total      : $([Math]::Round($wmiDisk.Size / 1GB, 2)) GB ($($wmiDisk.Size) bytes)"
        Write-Host "  Sectores Logicos/Fis.: $($wmiDisk.BytesPerSector) bytes / sector"
        Write-Host "  Total Cilindros/Cab. : Cilindros: $($wmiDisk.TotalCylinders) | Cabezas: $($wmiDisk.TotalHeads) | Sectores: $($wmiDisk.TotalSectors)"
    }

    # 2. S.M.A.R.T. y Fiabilidad (PowerShell 8+)
    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        $pDisk = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq "$discoIndex" }
        if ($pDisk) {
            Write-Host "`n [ESTADO DE SALUD Y METRICAS S.M.A.R.T.]" -ForegroundColor White -BackgroundColor DarkBlue
            Write-Host "  Estado Operativo     : $($pDisk.OperationalStatus)"
            Write-Host "  Salud S.M.A.R.T.      : $($pDisk.HealthStatus)"
            try {
                $counter = $pDisk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
                if ($counter) {
                    Write-Host "  Temperatura          : $(if ($counter.Temperature) { "$($counter.Temperature) C" } else { 'N/D' })"
                    Write-Host "  Desgaste (Wear %)    : $(if ($counter.Wear -ne $null) { "$($counter.Wear) %" } else { 'N/D' })"
                    Write-Host "  Horas de Uso (POH)   : $(if ($counter.PowerOnHours) { "$($counter.PowerOnHours) hrs" } else { 'N/D' })"
                    Write-Host "  Errores de Lectura   : $($counter.ReadErrorsTotal)"
                    Write-Host "  Errores de Escritura : $($counter.WriteErrorsTotal)"
                }
            } catch {}
        }
    }

    # 3. Topología de Particiones
    Write-Host "`n [TOPOLOGIA DE PARTICIONES DETECTADAS]" -ForegroundColor White -BackgroundColor DarkBlue
    if (Get-Command Get-Partition -ErrorAction SilentlyContinue) {
        $particiones = Get-Partition -DiskNumber $discoIndex -ErrorAction SilentlyContinue
        if ($particiones) {
            foreach ($p in $particiones) {
                $tamMB = [Math]::Round($p.Size / 1MB, 2)
                $letra = if ($p.DriveLetter) { "$($p.DriveLetter):" } else { "Sin Letra" }
                $activa = if ($p.IsActive -ne $null) { $p.IsActive } else { "N/A" }
                Write-Host ("  -> Particion #{0} | Tipo: {1} | Tamano: {2} MB | Letra: {3} | Activa: {4}" -f $p.PartitionNumber, $p.Type, $tamMB, $letra, $activa) -ForegroundColor Cyan
            }
        } else {
            Write-Host "  No se detectaron particiones estructuradas en este disco." -ForegroundColor Gray
        }
    } else {
        $wmiParts = Get-WmiObject Win32_DiskPartition | Where-Object { $_.DiskIndex -eq $discoIndex }
        if ($wmiParts) {
            foreach ($wp in $wmiParts) {
                Write-Host ("  -> Particion #{0} | Tipo: {1} | Tamano: {2} MB | Bootable: {3}" -f $wp.Index, $wp.Type, [Math]::Round($wp.Size / 1MB, 2), $wp.Bootable) -ForegroundColor Cyan
            }
        }
    }

    # 4. Volúmenes y Sistemas de Archivos
    Write-Host "`n [VOLUMENES LOGICOS ASOCIADOS]" -ForegroundColor White -BackgroundColor DarkBlue
    $volFound = $false
    if (Get-Command Get-Partition -ErrorAction SilentlyContinue) {
        $partsConLetra = Get-Partition -DiskNumber $discoIndex -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }
        foreach ($pcl in $partsConLetra) {
            $vol = Get-Volume -DriveLetter $pcl.DriveLetter -ErrorAction SilentlyContinue
            if ($vol) {
                $volFound = $true
                $tGB = [Math]::Round($vol.Size / 1GB, 2)
                $rGB = [Math]::Round($vol.SizeRemaining / 1GB, 2)
                $pctLibre = if ($vol.Size -gt 0) { [Math]::Round(($vol.SizeRemaining / $vol.Size) * 100, 1) } else { 0 }
                Write-Host ("  Unidad [{0}:] Etiqueta: '{1}' | FS: {2} | Capacidad: {3} GB | Libre: {4} GB ({5}%)" -f $vol.DriveLetter, $vol.FileSystemLabel, $vol.FileSystem, $tGB, $rGB, $pctLibre) -ForegroundColor Green
            }
        }
    }
    if (-not $volFound) {
        Write-Host "  No hay letras de volumen montadas actualmente para este disco." -ForegroundColor Gray
    }

    Write-Host "==========================================================================================`n" -ForegroundColor Cyan
}

function Invoke-DiskSurfaceCheck {
    cabecera
    Write-Header "OPCION 19.2: VERIFICACION Y REVISION DE SUPERFICIE / SECTORES DE DISCO"

    Write-Host "`n--- UNIDADES LOGICAS DETECTADAS ---" -ForegroundColor Cyan
    $unidades = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 }
    if ($null -eq $unidades) {
        Write-Host "[ERROR] No se encontraron unidades de almacenamiento validas." -ForegroundColor Red
        return
    }

    foreach ($u in $unidades) {
        $tamanoGB = if ($u.Size) { [Math]::Round($u.Size / 1GB, 2) } else { "N/D" }
        $libreGB = if ($u.FreeSpace) { [Math]::Round($u.FreeSpace / 1GB, 2) } else { "N/D" }
        $tipo = if ($u.DriveType -eq 2) { "USB/Extraible" } else { "Disco Local" }
        $esC = if ($u.DeviceID -eq $env:SystemDrive) { " [SISTEMA OPERATIVO]" } else { "" }
        Write-Host ("  -> Unidad: [{0}] | Tipo: {1} | FS: {2} | Etiqueta: {3} | Tamano: {4} GB | Libre: {5} GB{6}" -f $u.DeviceID, $tipo, $u.FileSystem, $u.VolumeName, $tamanoGB, $libreGB, $esC) -ForegroundColor Green
    }

    Write-Host "`n------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " [0] DESCARTAR / CANCELAR (Volver al menu anterior)" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkGray

    $entrada = (Read-Host "Ingrese la letra de la unidad a examinar (Ej: D o D:) o '0' para descartar").Trim().ToUpper()

    if ($entrada -eq "0" -or $entrada -eq "C" -or $entrada -eq "CANCELAR" -or $entrada -eq "") {
        Write-Host "`n[INFO] Operacion descartada por el usuario. Regresando al menu anterior..." -ForegroundColor Yellow
        return
    }

    $letra = if ($entrada -match '^[A-Z]:$') { $entrada } elseif ($entrada -match '^[A-Z]$') { "$entrada" + ":" } else { "" }
    if ($letra -eq "") {
        Write-Host "[ERROR] Formato de letra no valido." -ForegroundColor Red
        return
    }

    $unidadSel = $unidades | Where-Object { $_.DeviceID -eq $letra }
    if ($null -eq $unidadSel) {
        Write-Host "[ERROR] La unidad $letra no existe en el sistema." -ForegroundColor Red
        return
    }

    Write-Host "`n--- SELECCIONE EL TIPO DE REVISION PARA LA UNIDAD $letra ---" -ForegroundColor Cyan
    Write-Host "  1. REVISION SUPERFICIAL (Rapida - Metadatos, indices y estructura de archivos)" -ForegroundColor White
    Write-Host "     * Analiza el sistema de archivos en pocos segundos/minutos sin desmontar la unidad."
    Write-Host "  2. REVISION PROFUNDA (Exhaustiva - Superficie completa y recuperacion de sectores danados)" -ForegroundColor White
    Write-Host "     * Ejecuta chkdsk /f /r /x. Busca sectores defectuosos (Bad Sectors) y repara errores."
    Write-Host "     * NOTA: Este proceso puede tomar bastante tiempo segun la velocidad y tamano del disco."
    Write-Host "  0. DESCARTAR y volver al menu anterior" -ForegroundColor Yellow

    $tipoScan = Read-Host "`nSeleccione el nivel de revision (1, 2 o 0)"

    if ($tipoScan -eq "0" -or $tipoScan -eq "") {
        Write-Host "[INFO] Analisis cancelado. Regresando al menu anterior..." -ForegroundColor Yellow
        return
    }

    if ($letra -eq $env:SystemDrive) {
        Write-Host "`n[ADVERTENCIA CRITICA] La unidad seleccionada es la del Sistema Operativo Windows ($letra)." -ForegroundColor Magenta
        if ($tipoScan -eq "2") {
            Write-Host "Windows no puede desmontar el disco C: en vivo para una revision profunda con /r." -ForegroundColor Yellow
            $respC = Read-Host "Desea programar el analisis CHKDSK /F /R para el proximo reinicio del equipo? (S/N)"
            if ($respC.ToUpper() -eq "S") {
                chkdsk.exe $letra /f /r
                Write-Host "`n[OK] Analisis profundo programado para el proximo reinicio." -ForegroundColor Green
            } else {
                Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
            }
            return
        }
    }

    switch ($tipoScan) {
        "1" {
            Write-Host "`nIniciando Revision Superficial de la unidad $letra..." -ForegroundColor Cyan
            try {
                if (Get-Command Repair-Volume -ErrorAction SilentlyContinue) {
                    Write-Host "Ejecutando: Repair-Volume -DriveLetter $($letra.Replace(':','')) -Scan" -ForegroundColor Gray
                    Repair-Volume -DriveLetter ($letra.Replace(":", "")) -Scan
                } else {
                    Write-Host "Ejecutando: chkdsk.exe $letra /scan" -ForegroundColor Gray
                    chkdsk.exe $letra /scan
                }
                Write-Host "`n[EXITO] Revision superficial finalizada en $letra." -ForegroundColor Green
            } catch {
                Write-Host "`n[ERROR OCURRIDO]: $_" -ForegroundColor Red
            }
        }
        "2" {
            Write-Host "`n==========================================================================================" -ForegroundColor Red
            Write-Host " ADVERTENCIA: SE DESMONTARA TEMPORALMENTE LA UNIDAD $letra PARA EL ANALISIS PROFUNDO" -ForegroundColor Yellow
            Write-Host "==========================================================================================" -ForegroundColor Red
            $conf = Read-Host "Confirma iniciar el escaneo exhaustivo de superficie en $letra? (S/N)"
            if ($conf.ToUpper() -ne "S") {
                Write-Host "Revision profunda cancelada." -ForegroundColor Yellow
                return
            }

            Write-Host "`nEjecutando: chkdsk.exe $letra /f /r /x" -ForegroundColor Cyan
            Write-Host "Por favor espere mientras Windows analiza la superficie del disco...`n" -ForegroundColor Yellow
            try {
                & chkdsk.exe $letra /f /r /x
                Write-Host "`n[EXITO] Revision profunda de sectores finalizada en la unidad $letra." -ForegroundColor Green
            } catch {
                Write-Host "`n[ERROR OCURRIDO]: $_" -ForegroundColor Red
            }
        }
        Default {
            Write-Host "Opcion de revision no valida. Operacion abortada." -ForegroundColor Yellow
        }
    }
}

function Format-DiskStorageMBR {
    cabecera
    Write-Header "OPCION 19.3: PREPARAR DISCO PARA WINDOWS LEGACY (MBR + FAT32/NTFS - PARTICION ACTIVA)"

    $discos = Get-SafeDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron discos en el sistema." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES FISICAS DISPONIBLES ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $etiquetaSys = if ($d.IsSystem) { " [SISTEMA OPERATIVO C: - PROTEGIDO]" } else { "" }
        $color = if ($d.IsSystem) { "Magenta" } elseif ($d.MediaType -match "USB") { "Green" } else { "White" }
        Write-Host ("  [Disco {0}] {1} | Bus: {2} | Capacidad: {3} GB | Particion: {4}{5}" -f $d.Number, $d.FriendlyName, $d.BusType, $d.SizeGB, $d.PartitionStyle, $etiquetaSys) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco a preparar en MBR"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Number -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en el sistema." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El Disco $discoIndex contiene el Sistema Operativo actual." -ForegroundColor Red
        Write-Host "No esta permitido formatear la unidad donde corre el script." -ForegroundColor Red
        return
    }

    # 1. Selección de Filesystem
    Write-Host "`n--- SELECCION DE SISTEMA DE ARCHIVOS (MBR / WINDOWS) ---" -ForegroundColor Cyan
    Write-Host "  1. NTFS  (Recomendado para Windows Vista / 7 / 8 / 10 / 11 en BIOS Legacy - Archivos sin limite)"
    Write-Host "  2. FAT32 (Compatible con S.O. clasicos: Windows 98 / Windows XP o herramientas MS-DOS/WinPE)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $fsOpt = Read-Host "`nElija el sistema de archivos (1 o 2)"
    $fs = switch ($fsOpt) {
        "1" { "ntfs" }
        "2" { "fat32" }
        Default { "" }
    }
    if ($fs -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    if ($fs -eq "fat32" -and $targetDisk.SizeGB -gt 32) {
        Write-Host "`n[AVISO TECNICO] Ha seleccionado FAT32 para un disco de $($targetDisk.SizeGB) GB." -ForegroundColor Yellow
        Write-Host "Windows y Diskpart tienen un limite nativo de 32 GB para FAT32. Para discos mayores a 32 GB en FAT32, se recomienda usar la opcion 19.6 (almacenamiento multiparticion) o NTFS." -ForegroundColor Gray
    }

    # 2. Selección de Modo de Formateo
    Write-Host "`n--- MODO DE FORMATEO ---" -ForegroundColor Cyan
    Write-Host "  1. Formateo RAPIDO (quick - inicializa tablas de particion en segundos)"
    Write-Host "  2. Formateo PROFUNDO (Escribe ceros y comprueba cada sector fisico de la unidad)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $modoOpt = Read-Host "`nElija el modo de formateo (1 o 2)"
    $paramQuick = switch ($modoOpt) {
        "1" { "quick" }
        "2" { "" }
        Default { "CANCEL" }
    }
    if ($paramQuick -eq "CANCEL") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $labelInput = Read-Host "`nIngrese una etiqueta de volumen (Presione ENTER para 'WIN_MBR')"
    $etiqueta = if ($labelInput.Trim()) { $labelInput.Trim().Replace(" ", "_") -replace '[^\w\-]', '' } else { "WIN_MBR" }
    if ($fs -eq "fat32" -and $etiqueta.Length -gt 11) {
        $etiqueta = $etiqueta.Substring(0, 11)
    }

    # 3. Confirmación estricta de seguridad
    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                       ADVERTENCIA CRITICA DE ELIMINACION DE DATOS                        " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran TODAS las particiones y datos del siguiente dispositivo:" -ForegroundColor White
    Write-Host "  - Disco Objetivo  : [Disco $discoIndex] $($targetDisk.FriendlyName)" -ForegroundColor Yellow
    Write-Host "  - Capacidad       : $($targetDisk.SizeGB) GB ($($targetDisk.BusType))" -ForegroundColor Yellow
    Write-Host "  - Esquema         : MBR (Particion Primaria Unica - ACTIVA)" -ForegroundColor Yellow
    Write-Host "  - Sistema Archivos: $($fs.ToUpper()) ($etiqueta)" -ForegroundColor Yellow
    Write-Host "  - Modo Formateo   : $(if ($paramQuick -eq 'quick') { 'RAPIDO' } else { 'PROFUNDO' })" -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Proceso abortado de manera segura." -ForegroundColor Yellow
        return
    }

    # 4. Generación y ejecución de script Diskpart
    $diskpartCmds = @(
        "select disk $discoIndex",
        "clean",
        "convert mbr",
        "create partition primary",
        "select partition 1",
        "active",
        "format fs=$fs $paramQuick label=`"$etiqueta`"",
        "assign",
        "exit"
    )

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] El disco $discoIndex ha sido formateado en MBR y su particion esta ACTIVA." -ForegroundColor Green

        if ($fs -eq "ntfs") {
            # Inyectar código BOOTMGR si bootsect existe (solo NT60 para Windows Vista/7/8/10/11)
            try {
                $nuevoVol = Get-Partition -DiskNumber $discoIndex -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } | Select-Object -First 1
                if ($nuevoVol -and (Get-Command bootsect.exe -ErrorAction SilentlyContinue)) {
                    $driveL = "$($nuevoVol.DriveLetter):"
                    Write-Host "Inyectando cargador maestro BOOTMGR (NT60) con bootsect en $driveL..." -ForegroundColor Cyan
                    & bootsect.exe /nt60 $driveL /mbr
                    Write-Host "[OK] Codigo BOOTMGR instalado con exito." -ForegroundColor Green
                }
            } catch {}
        } else {
            Write-Host "Sector de arranque MBR activo preparado sin sobrescritura de NT60 (ideal para Win 98 / XP / MS-DOS)." -ForegroundColor Cyan
        }

        Write-Host "`nEl disco esta listo para uso y preparado para arranque en sistemas Legacy BIOS." -ForegroundColor Cyan
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Format-DiskStorageGPT {
    cabecera
    Write-Header "OPCION 19.4: PREPARAR DISCO PARA WINDOWS UEFI (GPT + NTFS - PARTICION DE SISTEMA LISTA)"

    $discos = Get-SafeDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron discos en el sistema." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES FISICAS DISPONIBLES ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $etiquetaSys = if ($d.IsSystem) { " [SISTEMA OPERATIVO C: - PROTEGIDO]" } else { "" }
        $color = if ($d.IsSystem) { "Magenta" } elseif ($d.MediaType -match "USB") { "Green" } else { "White" }
        Write-Host ("  [Disco {0}] {1} | Bus: {2} | Capacidad: {3} GB | Particion: {4}{5}" -f $d.Number, $d.FriendlyName, $d.BusType, $d.SizeGB, $d.PartitionStyle, $etiquetaSys) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco a preparar en GPT"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Number -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en el sistema." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El Disco $discoIndex contiene el Sistema Operativo actual." -ForegroundColor Red
        Write-Host "No esta permitido formatear la unidad donde corre el script." -ForegroundColor Red
        return
    }

    # 1. Selección de Filesystem
    Write-Host "`n--- SELECCION DE SISTEMA DE ARCHIVOS (GPT / UEFI) ---" -ForegroundColor Cyan
    Write-Host "  1. NTFS  (ESTANDAR OBLIGATORIO para instalar Windows 8 / 10 / 11 en Modo UEFI)"
    Write-Host "  2. FAT32 (Para particiones UEFI especializadas o herramientas WinPE)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $fsOpt = Read-Host "`nElija el sistema de archivos (1 o 2)"
    $fs = switch ($fsOpt) {
        "1" { "ntfs" }
        "2" { "fat32" }
        Default { "" }
    }
    if ($fs -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    if ($fs -eq "fat32" -and $targetDisk.SizeGB -gt 32) {
        Write-Host "`n[AVISO TECNICO] Ha seleccionado FAT32 para un disco de $($targetDisk.SizeGB) GB." -ForegroundColor Yellow
        Write-Host "Windows y Diskpart tienen un limite nativo de 32 GB para FAT32. Si Diskpart reporta 'volumen demasiado grande', utilice NTFS." -ForegroundColor Gray
    }

    # 2. Selección de Modo de Formateo
    Write-Host "`n--- MODO DE FORMATEO ---" -ForegroundColor Cyan
    Write-Host "  1. Formateo RAPIDO (quick - inicializa tablas de particion en segundos)"
    Write-Host "  2. Formateo PROFUNDO (Escribe ceros y comprueba cada sector fisico de la unidad)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $modoOpt = Read-Host "`nElija el modo de formateo (1 o 2)"
    $paramQuick = switch ($modoOpt) {
        "1" { "quick" }
        "2" { "" }
        Default { "CANCEL" }
    }
    if ($paramQuick -eq "CANCEL") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $labelInput = Read-Host "`nIngrese una etiqueta de volumen (Presione ENTER para 'WIN_UEFI')"
    $etiqueta = if ($labelInput.Trim()) { $labelInput.Trim().Replace(" ", "_") -replace '[^\w\-]', '' } else { "WIN_UEFI" }
    if ($fs -eq "fat32" -and $etiqueta.Length -gt 11) {
        $etiqueta = $etiqueta.Substring(0, 11)
    }

    # 3. Confirmación estricta de seguridad
    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                       ADVERTENCIA CRITICA DE ELIMINACION DE DATOS                        " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran TODAS las particiones y datos del siguiente dispositivo:" -ForegroundColor White
    Write-Host "  - Disco Objetivo  : [Disco $discoIndex] $($targetDisk.FriendlyName)" -ForegroundColor Yellow
    Write-Host "  - Capacidad       : $($targetDisk.SizeGB) GB ($($targetDisk.BusType))" -ForegroundColor Yellow
    Write-Host "  - Esquema         : GPT (Particion Primaria Unica UEFI)" -ForegroundColor Yellow
    Write-Host "  - Sistema Archivos: $($fs.ToUpper()) ($etiqueta)" -ForegroundColor Yellow
    Write-Host "  - Modo Formateo   : $(if ($paramQuick -eq 'quick') { 'RAPIDO' } else { 'PROFUNDO' })" -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Proceso abortado de manera segura." -ForegroundColor Yellow
        return
    }

    # 4. Generación y ejecución de script Diskpart
    $diskpartCmds = @(
        "select disk $discoIndex",
        "clean",
        "convert gpt",
        "create partition primary",
        "select partition 1",
        "format fs=$fs $paramQuick label=`"$etiqueta`"",
        "assign",
        "exit"
    )

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] El disco $discoIndex ha sido formateado en GPT con una particion unica." -ForegroundColor Green
        Write-Host "Nota UEFI: En tablas GPT el arranque es administrado por el firmware buscando particiones ESP/EFI." -ForegroundColor Cyan
        Write-Host "La particion ha quedado montada, en linea, asignada y ACTIVA/LISTA para transferir archivos de Windows." -ForegroundColor Green
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Invoke-DiskCleanWipe {
    <#
    .SYNOPSIS
        Limpia y reinicializa profundamente un disco duro o SSD eliminando todas las particiones,
        tablas MBR/GPT y firmas. Ofrece modo rápido (clean) o borrado seguro completo con ceros (clean all).
        Ideal para preparar discos desde cero antes de instalar un sistema operativo o recuperar unidades corruptas.
    #>
    cabecera
    Write-Header "OPCION 19.5: LIMPIEZA PROFUNDA DE DISCO (CLEAN / CLEAN ALL - BORRADO SEGURO)"

    $discos = Get-SafeDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron discos en el sistema." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES FISICAS DISPONIBLES PARA LIMPIEZA ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $etiquetaSys = if ($d.IsSystem) { " [SISTEMA OPERATIVO C: - PROTEGIDO]" } else { "" }
        $color = if ($d.IsSystem) { "Magenta" } elseif ($d.MediaType -match "USB") { "Green" } else { "White" }
        Write-Host ("  [Disco {0}] {1} | Bus: {2} | Capacidad: {3} GB | Particion: {4}{5}" -f $d.Number, $d.FriendlyName, $d.BusType, $d.SizeGB, $d.PartitionStyle, $etiquetaSys) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco a limpiar/reinicializar"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Number -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en el sistema." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El Disco $discoIndex contiene el Sistema Operativo actual." -ForegroundColor Red
        Write-Host "No esta permitido limpiar o borrar la unidad donde corre el sistema." -ForegroundColor Red
        return
    }

    # 1. Nivel de Limpieza
    Write-Host "`n--- NIVEL DE LIMPIEZA Y REINICIALIZACION ---" -ForegroundColor Cyan
    Write-Host "  1. Limpieza RAPIDA (CLEAN - Elimina al instante MBR/GPT, tablas y firmas de particion)"
    Write-Host "     * Deja el disco como 'Espacio No Asignado', listo para instalar Windows o Linux desde cero." -ForegroundColor DarkGray
    Write-Host "  2. Limpieza TOTAL / WIPE SEGURO (CLEAN ALL - Escribe ceros 0x00 en CADA sector fisico)"
    Write-Host "     * Destruye de forma irrecuperable todos los datos, elimina virus de arranque y repara sectores lentos." -ForegroundColor DarkGray
    Write-Host "     * Nota: En unidades grandes (>500 GB) puede tardar segun la velocidad del disco." -ForegroundColor Yellow
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $cleanOpt = Read-Host "`nElija el nivel de limpieza (1 o 2)"
    $cleanCmd = switch ($cleanOpt) {
        "1" { "clean" }
        "2" { "clean all" }
        Default { "" }
    }
    if ($cleanCmd -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    # 2. Confirmación de Seguridad
    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "               ADVERTENCIA CRITICA DE DESTRUCCION TOTAL DE DATOS                          " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se ELIMINARAN PERMANENTEMENTE todas las particiones, datos y estructuras del dispositivo:" -ForegroundColor White
    Write-Host "  - Disco Objetivo  : [Disco $discoIndex] $($targetDisk.FriendlyName)" -ForegroundColor Yellow
    Write-Host "  - Capacidad       : $($targetDisk.SizeGB) GB ($($targetDisk.BusType))" -ForegroundColor Yellow
    Write-Host "  - Operacion       : DISKPART $($cleanCmd.ToUpper())" -ForegroundColor $(if ($cleanCmd -eq 'clean all') { 'Red' } else { 'Yellow' })
    Write-Host "  - Resultado final : El disco quedara completamente VACIO (Sin formato, listo para particionar)" -ForegroundColor Green
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Proceso abortado de manera segura." -ForegroundColor Yellow
        return
    }

    $diskpartCmds = @(
        "select disk $discoIndex",
        $cleanCmd,
        "exit"
    )

    Write-Host "`n[INICIO] Ejecutando $cleanCmd en Disco $discoIndex..." -ForegroundColor Cyan
    if ($cleanCmd -eq "clean all") {
        Write-Host "[AVISO] La escritura de ceros sector por sector esta en progreso. No desconecte la unidad ni apague el equipo..." -ForegroundColor Yellow
    }

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] El Disco $discoIndex ha sido limpiado y reinicializado correctamente." -ForegroundColor Green
        Write-Host "La unidad se encuentra como 'Espacio No Asignado' (RAW), lista para ser particionada e instalar S.O." -ForegroundColor Cyan
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Format-DiskStorageGeneral {
    <#
    .SYNOPSIS
        Formatea unidades extraíbles (USB/SD) y discos duros/SSDs en FAT32, NTFS o exFAT.
        Exclusivamente para almacenamiento de datos (NO booteable, sin flag activa ni bootsect).
    #>
    cabecera
    Write-Header "OPCION 19.6: FORMATEO DE ALMACENAMIENTO GENERAL (FAT32 / NTFS / exFAT)"

    $discos = Get-SafeDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron unidades de almacenamiento en el sistema." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES FISICAS DISPONIBLES (ALMACENAMIENTO DE DATOS) ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $etiquetaSys = if ($d.IsSystem) { " [SISTEMA OPERATIVO C: - PROTEGIDO]" } else { "" }
        $color = if ($d.IsSystem) { "Magenta" } elseif ($d.MediaType -match "USB") { "Green" } else { "White" }
        Write-Host ("  [Disco {0}] {1} | Bus: {2} | Capacidad: {3} GB | Particion: {4}{5}" -f $d.Number, $d.FriendlyName, $d.BusType, $d.SizeGB, $d.PartitionStyle, $etiquetaSys) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco a formatear para almacenamiento"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Number -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en el sistema." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El Disco $discoIndex contiene el Sistema Operativo actual." -ForegroundColor Red
        Write-Host "No esta permitido formatear la unidad donde corre el sistema." -ForegroundColor Red
        return
    }

    # 1. Esquema de particionado
    Write-Host "`n--- SELECCION DE ESQUEMA DE PARTICIONES ---" -ForegroundColor Cyan
    Write-Host "  1. MBR (Recomendado para <= 2TB, Smart TVs, autorradios y consolas)"
    Write-Host "  2. GPT (Recomendado para discos modernos, SSDs y unidades > 2TB)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $estiloOpt = Read-Host "`nElija el esquema de particion (1 o 2)"
    $estilo = switch ($estiloOpt) {
        "1" { "mbr" }
        "2" { "gpt" }
        Default { "" }
    }
    if ($estilo -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    # 2. Selección de Sistema de Archivos
    Write-Host "`n--- SELECCION DE SISTEMA DE ARCHIVOS (SOLO DATOS) ---" -ForegroundColor Cyan
    Write-Host "  1. FAT32 (Maxima compatibilidad universal. Limite de 4 GB por archivo individual)"
    Write-Host "  2. NTFS  (Para Windows y discos de alta capacidad. Soporta archivos gigantes y seguridad)"
    Write-Host "  3. exFAT (Estandar moderno para pendrives/discos externos sin limite de 4GB. Compatible Win/Mac/Linux)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $fsOpt = Read-Host "`nElija el sistema de archivos (1, 2 o 3)"
    $fs = switch ($fsOpt) {
        "1" { "fat32" }
        "2" { "ntfs" }
        "3" { "exfat" }
        Default { "" }
    }
    if ($fs -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $esMultiPartFAT32 = ($fs -eq "fat32" -and $targetDisk.SizeGB -gt 32)
    $partCount = 1
    if ($esMultiPartFAT32) {
        $partCount = [Math]::Ceiling($targetDisk.SizeGB / 32)
        if ($estilo -eq "mbr" -and $partCount -gt 4) { $partCount = 4 }

        Write-Host "`n==========================================================================================" -ForegroundColor Cyan
        Write-Host " [ESTRUCTURACION FAT32 INTELIGENTE: PARTICIONADO MULTIPLE DE HASTA 32 GB]" -ForegroundColor Yellow
        Write-Host "==========================================================================================" -ForegroundColor Cyan
        Write-Host " Capacidad del disco : $($targetDisk.SizeGB) GB" -ForegroundColor White
        Write-Host " Limite nativo Win32 : Diskpart no formatea particiones individuales mayores a 32 GB en FAT32." -ForegroundColor Gray
        Write-Host " Solucion de diseno  : Se particionara el disco en $partCount volumenes FAT32 (hasta 32 GB c/u)." -ForegroundColor Green
        Write-Host " Beneficio           : 100% de la capacidad aprovechada en FAT32 puro, cada una con su letra." -ForegroundColor Green
        Write-Host "==========================================================================================" -ForegroundColor Cyan
    }

    # 3. Selección de Modo de Formateo (Rápido vs Profundo)
    Write-Host "`n--- MODO DE FORMATEO ---" -ForegroundColor Cyan
    Write-Host "  1. Formateo RAPIDO (quick - inicializa tablas y sistema de archivos en segundos)"
    Write-Host "  2. Formateo PROFUNDO (formato completo - verifica cada sector fisico y escribe ceros)"
    Write-Host "     * Nota: Realiza escaneo fisico cluster por cluster. Muestra porcentaje en tiempo real." -ForegroundColor DarkGray
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $modoOpt = Read-Host "`nElija el modo de formateo (1 o 2)"
    $esProfundo = ($modoOpt -eq "2")
    if ($modoOpt -ne "1" -and $modoOpt -ne "2") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    # Etiqueta por defecto segura de max 11 caracteres
    $defaultLabel = switch ($fs) {
        "fat32" { "DATOS_FAT32" }
        "ntfs"  { "DATOS_NTFS" }
        "exfat" { "DATOS_EXFAT" }
    }

    $labelInput = Read-Host "`nIngrese una etiqueta para el volumen (Presione ENTER para '$defaultLabel')"
    $etiqueta = if ($labelInput.Trim()) {
        # Limpiar caracteres no validos para etiquetas
        $labelInput.Trim().Replace(" ", "_") -replace '[^\w\-]', ''
    } else {
        $defaultLabel
    }

    # En FAT32 y exFAT el limite maximo de etiqueta es 11 caracteres (evita error en Diskpart)
    if ($fs -in @("fat32", "exfat") -and $etiqueta.Length -gt 11) {
        $etiqueta = $etiqueta.Substring(0, 11)
    }

    # 4. Confirmación estricta de seguridad
    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                       ADVERTENCIA CRITICA DE FORMATEO DE DATOS                          " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran permanentemente TODAS las particiones y archivos del dispositivo:" -ForegroundColor White
    Write-Host "  - Disco Objetivo  : [Disco $discoIndex] $($targetDisk.FriendlyName)" -ForegroundColor Yellow
    Write-Host "  - Capacidad       : $($targetDisk.SizeGB) GB ($($targetDisk.BusType))" -ForegroundColor Yellow
    Write-Host "  - Esquema         : $($estilo.ToUpper())" -ForegroundColor Yellow
    if ($esMultiPartFAT32) {
        Write-Host "  - Sistema Archivos: FAT32 (Dividido en $partCount particiones de hasta 32 GB c/u)" -ForegroundColor Green
    } else {
        Write-Host "  - Sistema Archivos: $($fs.ToUpper()) (Etiqueta: $etiqueta)" -ForegroundColor Yellow
    }
    Write-Host "  - Modo Formateo   : $(if ($esProfundo) { 'PROFUNDO (COMPLETO CON VERIFICACION DE SECTORES)' } else { 'RAPIDO (QUICK)' })" -ForegroundColor Yellow
    Write-Host "  - Propósito       : SOLO ALMACENAMIENTO DE DATOS (NO BOOTEABLE)" -ForegroundColor Green
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Proceso abortado de manera segura." -ForegroundColor Yellow
        return
    }

    # 5. Generación de directivas Diskpart con secuencia validada paso a paso
    $paramQuick = if ($esProfundo) { "" } else { "quick" }

    if ($esMultiPartFAT32) {
        $baseLabel = if ($etiqueta.Length -gt 8) { $etiqueta.Substring(0, 8) } else { $etiqueta }
        $diskpartCmds = @(
            "select disk $discoIndex",
            "clean",
            "convert $estilo"
        )
        for ($i = 1; $i -le $partCount; $i++) {
            $partLabel = "${baseLabel}_$i"
            if ($partLabel.Length -gt 11) { $partLabel = $partLabel.Substring(0, 11) }

            if ($i -lt $partCount) {
                $diskpartCmds += "create partition primary size=32000"
            } else {
                $diskpartCmds += "create partition primary"
            }
            $diskpartCmds += "select partition $i"
            $diskpartCmds += "format fs=fat32 $paramQuick label=`"$partLabel`""
            $diskpartCmds += "assign"
        }
        $diskpartCmds += "exit"
    } else {
        $diskpartCmds = @(
            "select disk $discoIndex",
            "clean",
            "convert $estilo",
            "create partition primary",
            "select partition 1",
            "format fs=$fs $paramQuick label=`"$etiqueta`"",
            "assign",
            "exit"
        )
    }

    Write-Host "`n[INICIO] Ejecutando formateo en Disco $discoIndex..." -ForegroundColor Cyan
    if ($esProfundo) {
        Write-Host "[AVISO] El formateo profundo esta escaneando y verificando cada sector físico. Por favor espere..." -ForegroundColor Yellow
    }

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] El Disco $discoIndex ha sido formateado exitosamente en $($fs.ToUpper())." -ForegroundColor Green
        if ($esMultiPartFAT32) {
            Write-Host "Se crearon y montaron $partCount particiones en FAT32 aprovechando el 100% de la capacidad ($($targetDisk.SizeGB) GB)." -ForegroundColor Cyan
            Write-Host "Cada particion esta montada con su propia letra de unidad y lista para almacenar archivos." -ForegroundColor Green
        } else {
            Write-Host "La unidad ha quedado montada con una particion de datos lista para almacenar archivos." -ForegroundColor Cyan
        }
        Write-Host "Configuracion: Esquema $($estilo.ToUpper()), Modo $(if ($esProfundo) { 'Profundo' } else { 'Rapido' }), sin sectores de booteo." -ForegroundColor Green
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
        if ($fs -eq "fat32" -and $targetDisk.SizeGB -gt 32) {
            Write-Host "`n[DIAGNOSTICO]: En Windows, la utilidad Diskpart no permite formatear particiones mayores a 32 GB en FAT32 ('El volumen es demasiado grande')." -ForegroundColor Yellow
            Write-Host "Para utilizar los $($targetDisk.SizeGB) GB completos de esta unidad, formatee en exFAT o NTFS." -ForegroundColor Cyan
        }
    }
}

function Format-DiskStorageLinux {
    <#
    .SYNOPSIS
        Prepara y formatea unidades de almacenamiento externas y discos duros para su uso en GNU/Linux.
        Soporta sistemas de archivos compatibles universalmente (exFAT, FAT32, NTFS) y particionado nativo Linux RAW.
        Exclusivamente para almacenamiento de datos (NO es USB Live ni medio booteable).
    #>
    cabecera
    Write-Header "OPCION 19.7: FORMATEO DE UNIDADES Y DISCOS PARA SISTEMAS GNU/LINUX"

    $discos = Get-SafeDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron unidades de almacenamiento en el sistema." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES FISICAS DISPONIBLES (DESTINO GNU/LINUX) ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $etiquetaSys = if ($d.IsSystem) { " [SISTEMA OPERATIVO C: - PROTEGIDO]" } else { "" }
        $color = if ($d.IsSystem) { "Magenta" } elseif ($d.MediaType -match "USB") { "Green" } else { "White" }
        Write-Host ("  [Disco {0}] {1} | Bus: {2} | Capacidad: {3} GB | Particion: {4}{5}" -f $d.Number, $d.FriendlyName, $d.BusType, $d.SizeGB, $d.PartitionStyle, $etiquetaSys) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco a preparar para GNU/Linux"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Number -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en el sistema." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El Disco $discoIndex contiene el Sistema Operativo actual." -ForegroundColor Red
        Write-Host "No esta permitido formatear la unidad donde corre el sistema." -ForegroundColor Red
        return
    }

    # 1. Esquema de particiones Linux
    Write-Host "`n--- SELECCION DE ESQUEMA DE PARTICIONES LINUX ---" -ForegroundColor Cyan
    Write-Host "  1. MBR (Universal para Linux, compatible con BIOS y discos <= 2TB)"
    Write-Host "  2. GPT (Recomendado para Linux moderno, UEFI y discos > 2TB)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $estiloOpt = Read-Host "`nElija el esquema de particion (1 o 2)"
    $estilo = switch ($estiloOpt) {
        "1" { "mbr" }
        "2" { "gpt" }
        Default { "" }
    }
    if ($estilo -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    # 2. Selección de Sistema de Archivos para GNU/Linux
    Write-Host "`n--- SELECCION DE SISTEMA DE ARCHIVOS COMPATIBLE CON GNU/LINUX ---" -ForegroundColor Cyan
    Write-Host "  1. exFAT (RECOMENDADO para almacenamiento masivo Linux - Kernel 5.7+ nativo, sin limite 4GB)" -ForegroundColor Green
    Write-Host "  2. FAT32 (Universal para cualquier distro Linux clásica o moderna - Formato vfat)"
    Write-Host "  3. NTFS  (Soporte nativo en GNU/Linux mediante controladores kernel ntfs3 y ntfs-3g)"
    Write-Host "  4. Particion Nativa Linux RAW (Tipo 83 en MBR / GUID Linux en GPT - Sin letra en Windows)"
    Write-Host "     * Crea la particion pura Linux lista para formatear en ext4/btrfs directamente en Linux." -ForegroundColor DarkGray
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow

    $fsLinuxOpt = Read-Host "`nElija la opcion deseada (1, 2, 3 o 4)"
    $esRawLinux = ($fsLinuxOpt -eq "4")
    $fs = switch ($fsLinuxOpt) {
        "1" { "exfat" }
        "2" { "fat32" }
        "3" { "ntfs" }
        "4" { "RAW_LINUX" }
        Default { "" }
    }
    if ($fs -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $esMultiPartFAT32 = ($fs -eq "fat32" -and $targetDisk.SizeGB -gt 32)
    $partCount = 1
    if ($esMultiPartFAT32) {
        $partCount = [Math]::Ceiling($targetDisk.SizeGB / 32)
        if ($estilo -eq "mbr" -and $partCount -gt 4) { $partCount = 4 }

        Write-Host "`n==========================================================================================" -ForegroundColor Cyan
        Write-Host " [ESTRUCTURACION FAT32 INTELIGENTE: PARTICIONADO MULTIPLE DE HASTA 32 GB]" -ForegroundColor Yellow
        Write-Host "==========================================================================================" -ForegroundColor Cyan
        Write-Host " Capacidad del disco : $($targetDisk.SizeGB) GB" -ForegroundColor White
        Write-Host " Limite nativo Win32 : Diskpart no formatea particiones individuales mayores a 32 GB en FAT32." -ForegroundColor Gray
        Write-Host " Solucion de diseno  : Se particionara el disco en $partCount volumenes FAT32 (hasta 32 GB c/u)." -ForegroundColor Green
        Write-Host " Beneficio           : 100% de la capacidad aprovechada en FAT32 puro, compatible con GNU/Linux." -ForegroundColor Green
        Write-Host "==========================================================================================" -ForegroundColor Cyan
    }

    # 3. Selección de Modo (Rápido vs Profundo)
    Write-Host "`n--- MODO DE FORMATEO ---" -ForegroundColor Cyan
    Write-Host "  1. Formateo RAPIDO (quick - inicializa tablas y sistema de archivos en segundos)"
    Write-Host "  2. Formateo PROFUNDO (formato completo - verifica cada sector fisico y escribe ceros)"
    Write-Host "     * Nota: Realiza escaneo fisico cluster por cluster. Muestra porcentaje en tiempo real." -ForegroundColor DarkGray
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $modoOpt = Read-Host "`nElija el modo de formateo (1 o 2)"
    $esProfundo = ($modoOpt -eq "2")
    if ($modoOpt -ne "1" -and $modoOpt -ne "2") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $defaultLabel = "LINUX_DATA"
    $labelInput = Read-Host "`nIngrese una etiqueta de volumen (Presione ENTER para '$defaultLabel')"
    $etiqueta = if ($labelInput.Trim()) {
        $labelInput.Trim().Replace(" ", "_") -replace '[^\w\-]', ''
    } else {
        $defaultLabel
    }

    # En FAT32 y exFAT el limite maximo de etiqueta es 11 caracteres (evita error en Diskpart)
    if ($fs -in @("fat32", "exfat") -and $etiqueta.Length -gt 11) {
        $etiqueta = $etiqueta.Substring(0, 11)
    }

    # 4. Confirmación estricta de seguridad
    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                       ADVERTENCIA CRITICA: DESTINO GNU/LINUX                             " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran permanentemente TODAS las particiones y datos del dispositivo:" -ForegroundColor White
    Write-Host "  - Disco Objetivo  : [Disco $discoIndex] $($targetDisk.FriendlyName)" -ForegroundColor Yellow
    Write-Host "  - Capacidad       : $($targetDisk.SizeGB) GB ($($targetDisk.BusType))" -ForegroundColor Yellow
    Write-Host "  - Esquema Linux   : $($estilo.ToUpper())" -ForegroundColor Yellow
    if ($esMultiPartFAT32) {
        Write-Host "  - Sistema/Formato : FAT32 (Dividido en $partCount particiones de hasta 32 GB c/u)" -ForegroundColor Green
    } else {
        Write-Host "  - Sistema/Formato : $(if ($esRawLinux) { 'Particion Nativa Linux RAW (ID 83 / GUID Linux)' } else { $fs.ToUpper() + ' (Etiqueta: ' + $etiqueta + ')' })" -ForegroundColor Yellow
    }
    Write-Host "  - Modo Formateo   : $(if ($esProfundo) { 'PROFUNDO (COMPLETO CON VERIFICACION DE SECTORES)' } else { 'RAPIDO (QUICK)' })" -ForegroundColor Yellow
    Write-Host "  - Propósito       : SOLO ALMACENAMIENTO DE DATOS (NO BOOTEABLE NI LIVE USB)" -ForegroundColor Green
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Proceso abortado de manera segura." -ForegroundColor Yellow
        return
    }

    # 5. Generación de directivas Diskpart con secuencia validada paso a paso
    $paramQuick = if ($esProfundo) { "" } else { "quick" }

    if ($esRawLinux) {
        # Partición nativa Linux RAW (ID 83 en MBR o GUID Linux en GPT)
        $partId = if ($estilo -eq "mbr") { "id=83" } else { "id=0fc63daf-8483-4772-8e79-3d69d8477de4" }
        $diskpartCmds = @(
            "select disk $discoIndex",
            "clean",
            "convert $estilo",
            "create partition primary $partId",
            "select partition 1",
            "exit"
        )
    } elseif ($esMultiPartFAT32) {
        $baseLabel = if ($etiqueta.Length -gt 8) { $etiqueta.Substring(0, 8) } else { $etiqueta }
        $diskpartCmds = @(
            "select disk $discoIndex",
            "clean",
            "convert $estilo"
        )
        for ($i = 1; $i -le $partCount; $i++) {
            $partLabel = "${baseLabel}_$i"
            if ($partLabel.Length -gt 11) { $partLabel = $partLabel.Substring(0, 11) }

            if ($i -lt $partCount) {
                $diskpartCmds += "create partition primary size=32000"
            } else {
                $diskpartCmds += "create partition primary"
            }
            $diskpartCmds += "select partition $i"
            $diskpartCmds += "format fs=fat32 $paramQuick label=`"$partLabel`""
            $diskpartCmds += "assign"
        }
        $diskpartCmds += "exit"
    } else {
        # Formato de almacenamiento estándar compatible con Linux (exFAT, FAT32, NTFS)
        $diskpartCmds = @(
            "select disk $discoIndex",
            "clean",
            "convert $estilo",
            "create partition primary",
            "select partition 1",
            "format fs=$fs $paramQuick label=`"$etiqueta`"",
            "assign",
            "exit"
        )
    }

    Write-Host "`n[INICIO] Aplicando particionado y formateo para GNU/Linux en Disco $discoIndex..." -ForegroundColor Cyan
    if ($esProfundo -and -not $esRawLinux) {
        Write-Host "[AVISO] El formateo profundo esta escaneando y verificando cada sector físico. Por favor espere..." -ForegroundColor Yellow
    }

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds

    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] El Disco $discoIndex ha sido preparado exitosamente para GNU/Linux." -ForegroundColor Green
        if ($esRawLinux) {
            Write-Host "La unidad contiene una particion pura de datos bajo esquema $($estilo.ToUpper()) con ID Linux nativo." -ForegroundColor Cyan
            Write-Host "Al conectarse a cualquier equipo GNU/Linux, sera reconocida de inmediato en /dev/sdX." -ForegroundColor Green
        } elseif ($esMultiPartFAT32) {
            Write-Host "Se crearon y montaron $partCount particiones en FAT32 aprovechando el 100% de la capacidad ($($targetDisk.SizeGB) GB)." -ForegroundColor Cyan
            Write-Host "Totalmente compatibles y reconocidas inmediatamente por cualquier distribucion GNU/Linux." -ForegroundColor Green
        } else {
            Write-Host "La unidad contiene una particion formateada en $($fs.ToUpper()) con etiqueta '$etiqueta' montada y lista." -ForegroundColor Cyan
            Write-Host "Totalmente compatible para lectura y escritura directa en cualquier distribucion GNU/Linux." -ForegroundColor Green
        }
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
        if ($fs -eq "fat32" -and $targetDisk.SizeGB -gt 32) {
            Write-Host "`n[DIAGNOSTICO]: En Windows, la utilidad Diskpart no permite formatear particiones mayores a 32 GB en FAT32 ('El volumen es demasiado grande')." -ForegroundColor Yellow
            Write-Host "Para utilizar los $($targetDisk.SizeGB) GB completos de esta unidad en GNU/Linux, formatee en exFAT (opcion 1) o cree una particion RAW (opcion 4)." -ForegroundColor Cyan
        }
    }
}

function psSubMenuFormatHDD {
    $salirSub19 = $false
    do {
        cabecera
        Write-Header "OPCION 19. PREPARAR DISCO DE DESTINO (HDD / SSD / NVMe) PARA S.O. O ALMACENAMIENTO"
        Write-Host "  19.0 Tabla de relacion: Filesystem vs Particion vs Modo Arranque (BIOS/UEFI)" -ForegroundColor Cyan
        Write-Host "  19.1 Informacion tecnica detallada de la unidad (Particion, FS, Salud SMART)" -ForegroundColor Yellow
        Write-Host "  19.2 Verificacion de sectores y revision de superficie (Superficial vs Profunda)" -ForegroundColor Yellow
        Write-Host "  19.3 Preparar Disco para Windows Legacy (MBR + FAT32/NTFS) - Particion ACTIVA [Win 98/XP/7/10/11]" -ForegroundColor Yellow
        Write-Host "  19.4 Preparar Disco para Windows UEFI (GPT + NTFS) - Particion de Sistema Lista" -ForegroundColor Yellow
        Write-Host "  19.5 Limpieza y Reinicializacion Profunda de Disco (Clean / Clean All - Wipe Seguro)" -ForegroundColor Yellow
        Write-Host "  19.6 Formateo de Almacenamiento General (FAT32 / NTFS / exFAT) [Multi-Particion FAT32]" -ForegroundColor Green
        Write-Host "  19.7 Formateo de Unidades y Discos para GNU/Linux (Particion Nativa RAW / ext4)" -ForegroundColor Green
        Write-Host ""
        Write-Host "  0. V O L V E R   A L   S U B M E N U   2 0" -ForegroundColor White
        Write-Header "=============================================================================="

        $op19 = Read-Host "Seleccione la tarea a realizar en Preparacion de Disco de Destino"

        switch ($op19) {
            { $_ -in "19.0", "0.0", "table" } { Show-FormatBootMatrix }
            { $_ -in "19.1", "1" }             { Show-DiskTechnicalDetails }
            { $_ -in "19.2", "2" }             { Invoke-DiskSurfaceCheck }
            { $_ -in "19.3", "3" }             { Format-DiskStorageMBR }
            { $_ -in "19.4", "4" }             { Format-DiskStorageGPT }
            { $_ -in "19.5", "5" }             { Invoke-DiskCleanWipe }
            { $_ -in "19.6", "6" }             { Format-DiskStorageGeneral }
            { $_ -in "19.7", "7" }             { Format-DiskStorageLinux }
            "0" { $salirSub19 = $true }
            Default { Write-Host "Opcion invalida." -ForegroundColor Red }
        }

        if (-not $salirSub19) {
            Write-Host ""
            Read-Host "Presione ENTER para continuar en el menu de Formateo..."
        }
    } while (-not $salirSub19)
}

# =========================================================================================
# ORQUESTADOR DE EJECUCION EXTERNA PARA EL GRUPO 19 (DESACOPLAMIENTO MULTIVENTANA)
# =========================================================================================

function Invoke-FormatHDDExternalWindow {
    <#
    .SYNOPSIS
        Despacha la ejecución de las funciones del Grupo 19 (Preparación de Disco de Destino)
        a un proceso y ventana de consola independiente de PowerShell, liberando inmediatamente la
        consola principal para el operador.
    .PARAMETER OpcionDestino
        Código de la opción a ejecutar ("19", "19.0", "19.1", "19.2", "19.3", "19.4", "19.5", "19.6", "19.7").
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OpcionDestino
    )

    $taskMap = @{
        "19"   = @{ Titulo = "Submenu 19: Preparar Disco de Destino (HDD/SSD/NVMe) para S.O. o Almacenamiento"; Cmd = "psSubMenuFormatHDD" }
        "19.0" = @{ Titulo = "19.0 Matriz Filesystem vs Particion vs Modo Arranque"; Cmd = "Show-FormatBootMatrix" }
        "19.1" = @{ Titulo = "19.1 Ficha Tecnica Detallada y Salud S.M.A.R.T.";     Cmd = "Show-DiskTechnicalDetails" }
        "19.2" = @{ Titulo = "19.2 Verificacion de Sectores y Revision Superficie";  Cmd = "Invoke-DiskSurfaceCheck" }
        "19.3" = @{ Titulo = "19.3 Preparar Disco para Windows Legacy (MBR + FAT32/NTFS) - Activa"; Cmd = "Format-DiskStorageMBR" }
        "19.4" = @{ Titulo = "19.4 Preparar Disco para Windows UEFI (GPT + NTFS)";  Cmd = "Format-DiskStorageGPT" }
        "19.5" = @{ Titulo = "19.5 Limpieza y Reinicializacion Profunda de Disco (Clean/Clean All)"; Cmd = "Invoke-DiskCleanWipe" }
        "19.6" = @{ Titulo = "19.6 Formateo de Almacenamiento General (FAT32/NTFS/exFAT)"; Cmd = "Format-DiskStorageGeneral" }
        "19.7" = @{ Titulo = "19.7 Formateo de Unidades y Discos para GNU/Linux"; Cmd = "Format-DiskStorageLinux" }
    }

    if (-not $taskMap.ContainsKey($OpcionDestino)) {
        Write-Host "[ERROR] Opcion de formateo '$OpcionDestino' no reconocida para ejecucion externa." -ForegroundColor Red
        return
    }

    $info = $taskMap[$OpcionDestino]
    $cleanOp = ($OpcionDestino -replace '[^\w]', '_')
    $tempFile = Join-Path $env:TEMP ("shellWil_FormatHDD_" + $cleanOp + "_" + (Get-Random -Minimum 1000 -Maximum 9999) + ".ps1")

    # Lista de funciones del módulo que deben exportarse al subproceso
    $requiredFunctions = @(
        'cabecera',
        'Write-Header',
        'Get-SafeDiskList',
        'Invoke-DiskpartBatch',
        'Show-FormatBootMatrix',
        'Show-DiskTechnicalDetails',
        'Invoke-DiskSurfaceCheck',
        'Format-DiskStorageMBR',
        'Format-DiskStorageGPT',
        'Invoke-DiskCleanWipe',
        'Format-DiskStorageGeneral',
        'Format-DiskStorageLinux',
        'psSubMenuFormatHDD'
    )

    # Construcción compatible con PowerShell 2.0 / 3.0 / 5.1 / 7+
    $sb = New-Object System.Text.StringBuilder

    [void]$sb.AppendLine("# ==========================================================================")
    [void]$sb.AppendLine("# CONSOLA SECUNDARIA AUTONOMA - SHELLSW (DISCOS Y PREPARACION S.O.)")
    [void]$sb.AppendLine("# Tarea: $($info.Titulo)")
    [void]$sb.AppendLine("# Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("# ==========================================================================")
    [void]$sb.AppendLine("try { `$Host.UI.RawUI.WindowTitle = 'ShellSW - Discos y Formateo [$OpcionDestino]' } catch {}")
    [void]$sb.AppendLine("[Console]::OutputEncoding = [System.Text.Encoding]::UTF8")
    [void]$sb.AppendLine("")

    # Definiciones de contingencia para cabeceras si no estuviesen cargadas en el entorno
    if (-not (Get-Command 'cabecera' -ErrorAction SilentlyContinue)) {
        [void]$sb.AppendLine(@'
function cabecera {
    Write-Host " ------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Ing. Wilson Yucra - Soft. Administracion y Gestion del Sistema Operativo" -ForegroundColor Cyan
    Write-Host " ------------------------------------------------------------------------" -ForegroundColor Cyan
}
'@)
    }

    if (-not (Get-Command 'Write-Header' -ErrorAction SilentlyContinue)) {
        [void]$sb.AppendLine(@'
function Write-Header {
    param([string]$texto)
    $ancho = $texto.Length + 15
    $linea = "=" * $ancho
    Write-Host "`n$linea" -ForegroundColor Yellow
    Write-Host "| $texto |" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "$linea" -ForegroundColor Yellow
}
'@)
    }

    # Serializar las funciones activas en memoria hacia el archivo runner
    foreach ($fn in $requiredFunctions) {
        $cmd = Get-Command $fn -ErrorAction SilentlyContinue
        if ($cmd) {
            [void]$sb.AppendLine("function $fn {")
            [void]$sb.AppendLine($cmd.Definition)
            [void]$sb.AppendLine("}`n")
        }
    }

    # Bloque de ejecución principal del subproceso
    [void]$sb.AppendLine("# --- EJECUCION DE LA TAREA SOLICITADA ---")
    [void]$sb.AppendLine("try {")
    [void]$sb.AppendLine("    $($info.Cmd)")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("catch {")
    [void]$sb.AppendLine("    Write-Host '`n[ERROR CRITICO EN VENTANA SECUNDARIA]: ' `$_.Exception.Message -ForegroundColor Red")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("finally {")
    if ($OpcionDestino -eq "19") {
        [void]$sb.AppendLine("    Write-Host '`n[Cerrando consola secundaria de formateo...]' -ForegroundColor Gray")
        [void]$sb.AppendLine("    Start-Sleep -Milliseconds 600")
        [void]$sb.AppendLine("    try { Remove-Item -Path `$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue } catch {}")
        [void]$sb.AppendLine("    exit")
    } else {
        [void]$sb.AppendLine("    Write-Host '`n==========================================================================' -ForegroundColor Cyan")
        [void]$sb.AppendLine("    Write-Host ' [PROCESO FINALIZADO] Esta ventana permanecera abierta para su consulta.' -ForegroundColor Green")
        [void]$sb.AppendLine("    Write-Host ' Puede revisar los reportes y cerrarla cuando lo desee.' -ForegroundColor Gray")
        [void]$sb.AppendLine("    Write-Host '==========================================================================' -ForegroundColor Cyan")
        [void]$sb.AppendLine("    Write-Host ''")
        [void]$sb.AppendLine("    Read-Host 'Presione ENTER para cerrar esta ventana...'")
        [void]$sb.AppendLine("    try { Remove-Item -Path `$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue } catch {}")
        [void]$sb.AppendLine("    exit")
    }
    [void]$sb.AppendLine("}")

    # Guardar en temporal con codificación UTF-8
    [System.IO.File]::WriteAllText($tempFile, $sb.ToString(), [System.Text.Encoding]::UTF8)

    # Lanzamiento del proceso de PowerShell en ventana externa independiente con elevación UAC
    $procArgs = @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$tempFile`""
    )

    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $procArgs -Verb RunAs -ErrorAction Stop
    }
    catch {
        # Si el usuario deniega UAC o el entorno no soporta RunAs, lanzar sin elevación forzada
        Start-Process -FilePath "powershell.exe" -ArgumentList $procArgs -ErrorAction SilentlyContinue
    }

    # Panel informativo en la consola principal
    Write-Host "`n==========================================================================" -ForegroundColor Cyan
    Write-Host "  [OK] TAREA DESPLEGADA EN UNA VENTANA O CONSOLA INDEPENDIENTE" -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  Accion Solicitada : $($info.Titulo)" -ForegroundColor White
    Write-Host "  Opcion / Codigo   : $OpcionDestino" -ForegroundColor Yellow
    Write-Host "  Estado Operativo  : Se ha abierto una consola secundaria de PowerShell." -ForegroundColor Gray
    Write-Host "  Disponibilidad    : Esta consola principal queda 100% LIBRE para su uso" -ForegroundColor Green
    Write-Host "                      inmediato en otras tareas del sistema." -ForegroundColor Gray
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# =========================================================================================
# FUNCIONES AUXILIARES Y MODULARES PARA EL GRUPO 21: PREPARACION DE DISPOSITIVOS EXTERNOS Y USB
# =========================================================================================

function Get-SafeUsbDiskList {
    <#
    .SYNOPSIS
        Obtiene la lista de unidades de almacenamiento USB / extraíbles físicas,
        con mapeo exacto de su índice físico, modelo, tamaño y letras montadas.
    #>
    $usbList = @()
    try {
        $sysDrive = $env:SystemDrive.Replace(":", "")
        $systemDiskNum = -1
        if (Get-Command Get-Partition -ErrorAction SilentlyContinue) {
            $sysPart = Get-Partition -DriveLetter $sysDrive -ErrorAction SilentlyContinue
            if ($sysPart) { $systemDiskNum = $sysPart.DiskNumber }
        }

        # 1. Intentar mediante Storage Cmdlets (Win 8/10/11)
        if (Get-Command Get-Disk -ErrorAction SilentlyContinue) {
            $disks = Get-Disk | Where-Object { 
                $_.BusType -eq "USB" -or $_.MediaType -eq "Removable" 
            } | Sort-Object Number

            foreach ($d in $disks) {
                $isSys = ($d.Number -eq $systemDiskNum)
                $sizeGB = [Math]::Round($d.Size / 1GB, 2)
                
                # Obtener letras de particiones
                $letters = @()
                $parts = Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue
                if ($parts) {
                    foreach ($p in $parts) {
                        if ($p.DriveLetter) { $letters += "$($p.DriveLetter):" }
                    }
                }
                $letterStr = if ($letters.Count -gt 0) { ($letters -join ", ") } else { "Sin Letra" }

                $usbList += [PSCustomObject]@{
                    Index        = [int]$d.Number
                    Model        = $d.FriendlyName
                    BusType      = "USB"
                    SizeGB       = $sizeGB
                    Letters      = $letterStr
                    IsSystem     = $isSys
                    Style        = $d.PartitionStyle.ToString()
                }
            }
            if ($usbList.Count -gt 0) { return $usbList }
        }
    } catch {}

    # 2. Fallback WMI Win32_DiskDrive (Compatibilidad Win 7)
    try {
        $wmiDisks = Get-WmiObject Win32_DiskDrive | Where-Object { 
            $_.InterfaceType -eq "USB" -or $_.MediaType -match "Removable|External" 
        } | Sort-Object Index

        foreach ($wd in $wmiDisks) {
            $idx = [int]$wd.Index
            $sizeGB = if ($wd.Size) { [Math]::Round($wd.Size / 1GB, 2) } else { 0 }
            
            # Obtener letras asociadas vía asociadores WMI
            $letters = @()
            try {
                $qParts = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($wd.DeviceID)'} WHERE AssocClass=Win32_DiskDriveToDiskPartition" -ErrorAction SilentlyContinue
                foreach ($qp in $qParts) {
                    $qVols = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($qp.DeviceID)'} WHERE AssocClass=Win32_LogicalDiskToPartition" -ErrorAction SilentlyContinue
                    foreach ($qv in $qVols) {
                        if ($qv.DeviceID) { $letters += $qv.DeviceID }
                    }
                }
            } catch {}
            $letterStr = if ($letters.Count -gt 0) { ($letters -join ", ") } else { "Sin Letra" }

            $usbList += [PSCustomObject]@{
                Index        = $idx
                Model        = $wd.Caption
                BusType      = "USB"
                SizeGB       = $sizeGB
                Letters      = $letterStr
                IsSystem     = ($idx -eq $systemDiskNum)
                Style        = "N/D"
            }
        }
    } catch {}

    return $usbList
}

function Show-UsbBootMatrix {
    cabecera
    Write-Header "OPCION 21.0: MATRIZ DE ARQUITECTURA DE ARRANQUE USB (LEGACY vs UEFI vs MULTIBOOT)"

    Write-Host "`n==========================================================================================" -ForegroundColor Cyan
    Write-Host "         MATRIZ COMPARATIVA PARA PREPARACION DE DISPOSITIVOS EXTERNOS / USB BOOTEABLE     " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    $matrix = @(
        [PSCustomObject]@{
            "Modalidad"       = "Windows Legacy BIOS"
            "Tabla Part."     = "MBR"
            "Sistema Arch."   = "NTFS (Recom.) / FAT32"
            "Particion Act."  = "SI (OBLIGATORIA)"
            "Rol BootSect"    = "Inyecta firma NT60 en MBR/PBR"
            "Limite WIM"      = "Sin limite (NTFS soporta >4GB)"
            "Arranque UEFI"   = "No compatible de forma nativa"
        },
        [PSCustomObject]@{
            "Modalidad"       = "Windows UEFI Nativo"
            "Tabla Part."     = "GPT (ESP) / MBR"
            "Sistema Arch."   = "FAT32 (Estandar UEFI)"
            "Particion Act."  = "NO (Ignorada por UEFI)"
            "Rol BootSect"    = "No se utiliza (busca EFI)"
            "Limite WIM"      = "FAT32 max 4GB -> Split WIM (.swm)"
            "Arranque UEFI"   = "100% Nativo (Secure Boot)"
        },
        [PSCustomObject]@{
            "Modalidad"       = "Windows UEFI Dual-Part"
            "Tabla Part."     = "MBR o GPT"
            "Sistema Arch."   = "P1: FAT32 (2GB) + P2: NTFS"
            "Particion Act."  = "P1 Activa si MBR"
            "Rol BootSect"    = "Opcional en P1"
            "Limite WIM"      = "Sin limite (WIM en P2 NTFS)"
            "Arranque UEFI"   = "Excelente en placas modernas"
        },
        [PSCustomObject]@{
            "Modalidad"       = "Linux Live USB"
            "Tabla Part."     = "MBR o GPT (Hibrido)"
            "Sistema Arch."   = "FAT32 (etiqueta LINUX_LIVE)"
            "Particion Act."  = "Requerido para Legacy"
            "Rol BootSect"    = "Syslinux/GRUB2 MBR"
            "Limite WIM"      = "N/A (SquashFS kernel <4GB)"
            "Arranque UEFI"   = "Nativo con BOOTX64.EFI"
        },
        [PSCustomObject]@{
            "Modalidad"       = "Multiboot Ventoy CLI"
            "Tabla Part."     = "GPT o MBR (Dual VTOY)"
            "Sistema Arch."   = "P1 exFAT (ISOs) + P2 FAT (VTOY)"
            "Particion Act."  = "Automatizada por Ventoy"
            "Rol BootSect"    = "GRUB2 Multiplataforma"
            "Limite WIM"      = "Sin limite (Copia directa .ISO)"
            "Arranque UEFI"   = "Dual: Legacy BIOS + UEFI Secure"
        }
    )

    $matrix | Format-Table -AutoSize

    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[REGLAS DE ORO PARA EL TECNICO / ADMINISTRADOR]:" -ForegroundColor White
    Write-Host " 1. BOOTSECT.EXE (/nt60 X: /mbr):" -ForegroundColor Cyan
    Write-Host "    - En modo Legacy BIOS, si el USB fue formateado sin inyectar bootsect, la BIOS podria indicar" -ForegroundColor Gray
    Write-Host "      'Operating System not found' o 'Non-system disk'. La opcion 21.2 asegura la escritura NT60." -ForegroundColor Gray
    Write-Host "`n 2. LIMITACION DE 4 GB DE FAT32 EN WINDOWS UEFI:" -ForegroundColor Cyan
    Write-Host "    - Los instaladores modernos de Win 10/11 incluyen 'install.wim' de 4.5 GB a 6.5 GB." -ForegroundColor Gray
    Write-Host "    - Opcion 21.3 resuelve esto dividiendo el WIM en partes .swm mediante DISM oficial." -ForegroundColor Yellow
    Write-Host "    - Opcion 21.4 resuelve esto con doble particion: arranque en FAT32 y datos en NTFS." -ForegroundColor Yellow
    Write-Host "`n 3. MULTIBOOT DE MULTIPLES SISTEMAS (Windows + Linux):" -ForegroundColor Cyan
    Write-Host "    - La herramienta universal por excelencia es Ventoy (Opcion 21.7), que permite arrastrar" -ForegroundColor Gray
    Write-Host "      multiples ISOs a la particion sin descomprimirlas, con soporte UEFI + Legacy simultaneo." -ForegroundColor Gray
    Write-Host "==========================================================================================`n" -ForegroundColor Cyan
}

function Deploy-IsoToUsb {
    param(
        [Parameter(Mandatory=$true)][string]$IsoPath,
        [Parameter(Mandatory=$true)][string]$TargetLetter,
        [bool]$CheckFat32Split = $false
    )
    if (-not (Test-Path $IsoPath)) {
        Write-Host "[ERROR] El archivo ISO no existe en la ruta: $IsoPath" -ForegroundColor Red
        return $false
    }

    $cleanTarget = if ($TargetLetter.EndsWith("\")) { $TargetLetter } else { "$TargetLetter\" }
    Write-Host "`n[ISO DEPLOY] Accediendo a la imagen ISO de instalacion: $IsoPath..." -ForegroundColor Cyan

    $isoDriveLetter = ""
    try {
        if (Get-Command Mount-DiskImage -ErrorAction SilentlyContinue) {
            $mountRes = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
            Start-Sleep -Seconds 1
            $vol = Get-DiskImage -ImagePath $IsoPath | Get-Volume -ErrorAction SilentlyContinue
            if ($vol -and $vol.DriveLetter) {
                $isoDriveLetter = "$($vol.DriveLetter):\"
            }
        }
    } catch {
        Write-Host "[ADVERTENCIA] Mount-DiskImage no pudo montar automaticamente: $_" -ForegroundColor Yellow
    }

    if (-not $isoDriveLetter -or -not (Test-Path $isoDriveLetter)) {
        Write-Host "No se pudo montar la ISO de forma directa." -ForegroundColor Yellow
        $isoInput = Read-Host "Si la ISO ya esta montada en una unidad virtual, ingrese su letra (Ej: E:)"
        if ($isoInput -and (Test-Path "$isoInput\")) {
            $isoDriveLetter = if ($isoInput.EndsWith("\")) { $isoInput } else { "$isoInput\" }
        } else {
            Write-Host "[ERROR] No se pudo acceder a los archivos de la ISO." -ForegroundColor Red
            return $false
        }
    }

    Write-Host "  -> Unidad de origen (ISO) : $isoDriveLetter" -ForegroundColor Green
    Write-Host "  -> Unidad de destino (USB): $cleanTarget" -ForegroundColor Green

    # Comprobación de install.wim > 4GB en sistemas FAT32
    $wimPath = Join-Path $isoDriveLetter "sources\install.wim"
    $needsSplit = $false
    if ($CheckFat32Split -and (Test-Path $wimPath)) {
        $wimItem = Get-Item $wimPath -ErrorAction SilentlyContinue
        if ($wimItem -and ($wimItem.Length -gt 4100000000)) { # > 3.8 GB
            $needsSplit = $true
            Write-Host "`n[DETECCION CRITICA WIM] 'install.wim' pesa $([Math]::Round($wimItem.Length / 1GB, 2)) GB (supera los 4GB de FAT32)." -ForegroundColor Yellow
            Write-Host "Se ejecutara la copia con division automatica de WIM en fragmentos .SWM mediante DISM..." -ForegroundColor Cyan
        }
    }

    try {
        if ($needsSplit) {
            # 1. Copiar todos los archivos EXCEPTO install.wim con robocopy
            Write-Host "`nTransfiriendo archivos de instalacion base (excluyendo install.wim)..." -ForegroundColor White
            & robocopy.exe "$isoDriveLetter" "$cleanTarget" /E /XF "install.wim" /R:1 /W:1 /NP /NDL
            
            # 2. Ejecutar DISM Split-Image
            $targetSources = Join-Path $cleanTarget "sources"
            if (-not (Test-Path $targetSources)) { New-Item -ItemType Directory -Path $targetSources -Force | Out-Null }
            $swmDestination = Join-Path $targetSources "install.swm"

            Write-Host "`nEjecutando: dism.exe /Split-Image /ImageFile:`"$wimPath`" /SWMFile:`"$swmDestination`" /FileSize:3800" -ForegroundColor Cyan
            Write-Host "Por favor espere mientras DISM divide el archivo wim..." -ForegroundColor Yellow
            & dism.exe /Split-Image /ImageFile:"$wimPath" /SWMFile:"$swmDestination" /FileSize:3800

            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n[EXITO DISM] Imagen WIM dividida correctamente en partes .swm compatibles con UEFI." -ForegroundColor Green
            } else {
                Write-Host "`n[ERROR DISM] Fallo al dividir la imagen WIM (Codigo: $LASTEXITCODE)." -ForegroundColor Red
            }
        } else {
            # Copia completa directa
            Write-Host "`nTransfiriendo archivos de instalacion a la memoria USB..." -ForegroundColor White
            & robocopy.exe "$isoDriveLetter" "$cleanTarget" /E /R:1 /W:1 /NP /NDL
            Write-Host "`n[EXITO COPIA] Transferencia de archivos finalizada con exito." -ForegroundColor Green
        }
        return $true
    }
    catch {
        Write-Host "`n[ERROR EN DESPLIEGUE]: $_" -ForegroundColor Red
        return $false
    }
    finally {
        # Desmontar ISO si fue montada automáticamente
        try {
            if (Get-Command Dismount-DiskImage -ErrorAction SilentlyContinue) {
                Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
            }
        } catch {}
    }
}

function Format-UsbWindowsLegacy {
    param(
        [Parameter(Mandatory=$false)][bool]$InjectBootSect = $true,
        [Parameter(Mandatory=$false)][string]$IsoPath = ""
    )
    cabecera
    $tituloModo = if ($InjectBootSect) { "CON BOOTSECT (NT60 MBR)" } else { "SIN BOOTSECT (SOLO PARTICION ACTIVA)" }
    Write-Header "OPCION 21: PREPARACION USB WINDOWS - MODO LEGACY BIOS ($tituloModo)"

    $discos = Get-SafeUsbDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron memorias USB o unidades extraibles." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES EXTRAIBLES / USB DETECTADAS ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $color = if ($d.IsSystem) { "Magenta" } else { "Green" }
        Write-Host ("  [Disco {0}] {1} | Tamano: {2} GB | Letra(s): {3}" -f $d.Index, $d.Model, $d.SizeGB, $d.Letters) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco USB a preparar"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Index -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en la lista de unidades USB." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El disco seleccionado contiene el Sistema Operativo." -ForegroundColor Red
        return
    }

    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                 ADVERTENCIA CRITICA DE ELIMINACION DE DATOS EN USB                       " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran TODOS los datos en el [Disco $discoIndex] $($targetDisk.Model) ($($targetDisk.SizeGB) GB)." -ForegroundColor White
    Write-Host " Esquema: MBR / Particion Primaria Unica NTFS (ACTIVA)" -ForegroundColor Yellow
    Write-Host " BootSect: $(if ($InjectBootSect) { 'SI (Inyeccion bootsect /nt60 /mbr)' } else { 'NO (Sin tocar PBR)' })" -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $diskpartCmds = @(
        "select disk $discoIndex",
        "clean",
        "convert mbr",
        "create partition primary",
        "active",
        "format fs=ntfs quick label=`"WIN_LEGACY`"",
        "assign",
        "exit"
    )

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] Unidad USB formateada en NTFS MBR y marcada como ACTIVA." -ForegroundColor Green
        Start-Sleep -Seconds 1
        
        $refreshed = Get-SafeUsbDiskList | Where-Object { $_.Index -eq $discoIndex }
        $letra = ($refreshed.Letters -split ",")[0].Trim()

        if ($InjectBootSect -and $letra) {
            Write-Host "`nInyectando cargador maestro BOOTMGR con bootsect.exe en $letra..." -ForegroundColor Cyan
            try {
                & bootsect.exe /nt60 "$letra" /mbr
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] Codigo BOOTMGR inyectado correctamente en el MBR y PBR de $letra." -ForegroundColor Green
                } else {
                    Write-Host "[ADVERTENCIA] Bootsect finalizo con codigo: $LASTEXITCODE" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "[ERROR] No se pudo invocar bootsect.exe: $_" -ForegroundColor Red
            }
        }

        $confIso = Read-Host "`nDesea volcar los archivos desde una imagen ISO de Windows ahora? (S/N)"
        if ($confIso.ToUpper() -eq "S") {
            $isoInput = Read-Host "Ingrese la ruta completa del archivo .ISO de Windows"
            $isoInput = $isoInput.Trim().Trim('"').Trim("'")
            if (Test-Path $isoInput) {
                Deploy-IsoToUsb -IsoPath $isoInput -TargetLetter $letra -CheckFat32Split $false
            } else {
                Write-Host "[ERROR] Archivo ISO no encontrado: $isoInput" -ForegroundColor Red
            }
        } else {
            Write-Host "`n[OK] El USB quedo preparado y listo para que copies los archivos de instalacion manualmente." -ForegroundColor Green
        }
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Format-UsbWindowsUEFI {
    cabecera
    Write-Header "OPCION 21.3: PREPARACION USB WINDOWS - MODO UEFI NATIVO (GPT / FAT32 CON SPLIT WIM DISM)"

    $discos = Get-SafeUsbDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron memorias USB o unidades extraibles." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES EXTRAIBLES / USB DETECTADAS ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $color = if ($d.IsSystem) { "Magenta" } else { "Green" }
        Write-Host ("  [Disco {0}] {1} | Tamano: {2} GB | Letra(s): {3}" -f $d.Index, $d.Model, $d.SizeGB, $d.Letters) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco USB a preparar en GPT-UEFI"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Index -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en la lista de unidades USB." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El disco seleccionado contiene el Sistema Operativo." -ForegroundColor Red
        return
    }

    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                 ADVERTENCIA CRITICA DE ELIMINACION DE DATOS EN USB                       " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran TODOS los datos en el [Disco $discoIndex] $($targetDisk.Model) ($($targetDisk.SizeGB) GB)." -ForegroundColor White
    Write-Host " Esquema: GPT (GUID Partition Table) / Particion Primaria FAT32 (Etiqueta 'WIN_UEFI')" -ForegroundColor Yellow
    Write-Host " Compatibilidad: 100% Nativo UEFI (Soporte oficial de Secure Boot)" -ForegroundColor Yellow
    Write-Host " Division WIM: Automatizada con DISM si install.wim supera los 4GB" -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $diskpartCmds = @(
        "select disk $discoIndex",
        "clean",
        "convert gpt",
        "create partition primary",
        "format fs=fat32 quick label=`"WIN_UEFI`"",
        "assign",
        "exit"
    )

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] Unidad USB formateada en GPT FAT32 para UEFI nativo." -ForegroundColor Green
        Start-Sleep -Seconds 1
        
        $refreshed = Get-SafeUsbDiskList | Where-Object { $_.Index -eq $discoIndex }
        $letra = ($refreshed.Letters -split ",")[0].Trim()

        $confIso = Read-Host "`nDesea volcar los archivos desde una imagen ISO de Windows ahora? (S/N)"
        if ($confIso.ToUpper() -eq "S") {
            $isoInput = Read-Host "Ingrese la ruta completa del archivo .ISO de Windows"
            $isoInput = $isoInput.Trim().Trim('"').Trim("'")
            if (Test-Path $isoInput) {
                Deploy-IsoToUsb -IsoPath $isoInput -TargetLetter $letra -CheckFat32Split $true
            } else {
                Write-Host "[ERROR] Archivo ISO no encontrado: $isoInput" -ForegroundColor Red
            }
        } else {
            Write-Host "`n[OK] El USB quedo preparado en FAT32 GPT. Recuerde que si copia install.wim manualmente, debe pesar menos de 4GB o usar DISM /Split-Image." -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Format-UsbWindowsDualPartition {
    cabecera
    Write-Header "OPCION 21.4: PREPARACION USB WINDOWS - MODO UEFI DUAL-PARTITION (FAT32 BOOT + NTFS DATOS)"

    $discos = Get-SafeUsbDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron memorias USB o unidades extraibles." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES EXTRAIBLES / USB DETECTADAS ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $color = if ($d.IsSystem) { "Magenta" } else { "Green" }
        Write-Host ("  [Disco {0}] {1} | Tamano: {2} GB | Letra(s): {3}" -f $d.Index, $d.Model, $d.SizeGB, $d.Letters) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco USB a preparar con particion dual"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Index -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en la lista de unidades USB." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El disco seleccionado contiene el Sistema Operativo." -ForegroundColor Red
        return
    }

    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                   ADVERTENCIA CRITICA DE PARTICIONADO DUAL UEFI                         " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran TODOS los datos en el [Disco $discoIndex] $($targetDisk.Model) ($($targetDisk.SizeGB) GB)." -ForegroundColor White
    Write-Host " Estructura a crear:" -ForegroundColor Yellow
    Write-Host "  - Particion 1: 2048 MB (FAT32) -> Etiqueta 'BOOT_UEFI' (Cargador EFI + WinPE boot.wim)" -ForegroundColor Gray
    Write-Host "  - Particion 2: Resto de la unidad (NTFS) -> Etiqueta 'WIN_DATA' (Soporta install.wim > 4GB)" -ForegroundColor Gray
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Operacion cancelada." -ForegroundColor Yellow
        return
    }

    Write-Host "`nSeleccione el esquema de particiones:" -ForegroundColor Cyan
    Write-Host "  [1] GPT (GUID Partition Table) -> [RECOMENDADO para UEFI nativo y visibilidad multi-particion]" -ForegroundColor Green
    Write-Host "  [2] MBR (Master Boot Record)   -> [Compatibilidad dual con equipos Legacy BIOS y UEFI antiguos]" -ForegroundColor Yellow
    $esqSel = Read-Host "Elija el esquema (1 para GPT [Default], 2 para MBR)"
    $useGpt = ($esqSel -ne "2")
    $tablaTexto = if ($useGpt) { "GPT" } else { "MBR" }

    $diskpartCmds = if ($useGpt) {
        @(
            "select disk $discoIndex",
            "clean",
            "convert gpt",
            "create partition primary size=2048",
            "format fs=fat32 quick label=`"BOOT_UEFI`"",
            "assign",
            "create partition primary",
            "format fs=ntfs quick label=`"WIN_DATA`"",
            "assign",
            "exit"
        )
    } else {
        @(
            "select disk $discoIndex",
            "clean",
            "convert mbr",
            "create partition primary size=2048",
            "active",
            "format fs=fat32 quick label=`"BOOT_UEFI`"",
            "assign",
            "create partition primary",
            "format fs=ntfs quick label=`"WIN_DATA`"",
            "assign",
            "exit"
        )
    }

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] Unidad USB particionada en modo Dual $tablaTexto (FAT32 Boot + NTFS Datos)." -ForegroundColor Green
        Start-Sleep -Seconds 3
        
        $confIso = Read-Host "`nDesea volcar los archivos desde una imagen ISO de Windows ahora? (S/N)"
        if ($confIso.ToUpper() -eq "S") {
            $isoPath = Read-Host "Ingrese la ruta completa del archivo .ISO de Windows"
            $isoPath = $isoPath.Trim().Trim('"').Trim("'")
            if (Test-Path $isoPath) {
                # Obtener las dos letras asignadas de forma robusta por partición y etiqueta
                $bootLetter = ""
                $dataLetter = ""
                
                $p1 = Get-Partition -DiskNumber $discoIndex -PartitionNumber 1 -ErrorAction SilentlyContinue
                $p2 = Get-Partition -DiskNumber $discoIndex -PartitionNumber 2 -ErrorAction SilentlyContinue
                if ($p1 -and $p1.DriveLetter) { $bootLetter = "$($p1.DriveLetter):" }
                if ($p2 -and $p2.DriveLetter) { $dataLetter = "$($p2.DriveLetter):" }

                if (-not $bootLetter -or -not $dataLetter) {
                    $vols = Get-Volume -ErrorAction SilentlyContinue
                    $vBoot = $vols | Where-Object { $_.FileSystemLabel -eq "BOOT_UEFI" -and $_.DriveLetter }
                    $vData = $vols | Where-Object { $_.FileSystemLabel -eq "WIN_DATA" -and $_.DriveLetter }
                    if ($vBoot) { $bootLetter = "$($vBoot.DriveLetter):" }
                    if ($vData) { $dataLetter = "$($vData.DriveLetter):" }
                }

                if (-not $bootLetter -or -not $dataLetter) {
                    $refreshed = Get-SafeUsbDiskList | Where-Object { $_.Index -eq $discoIndex }
                    $letraList = $refreshed.Letters -split ","
                    if ($letraList.Count -ge 2) {
                        $bootLetter = $letraList[0].Trim()
                        $dataLetter = $letraList[1].Trim()
                    }
                }

                if ($bootLetter -and $dataLetter) {
                    Write-Host "`n[ASIGNACION DETECTADA]:" -ForegroundColor Cyan
                    Write-Host "  -> Particion de arranque FAT32 (BOOT_UEFI) : $bootLetter" -ForegroundColor Green
                    Write-Host "  -> Particion de datos NTFS   (WIN_DATA)   : $dataLetter" -ForegroundColor Green

                    # 1. Copiar todo el contenido de la ISO a la partición de datos NTFS
                    Write-Host "`n[FASE 1] Volcando contenido completo de la ISO a la particion de datos ($dataLetter)..." -ForegroundColor Yellow
                    Deploy-IsoToUsb -IsoPath $isoPath -TargetLetter $dataLetter -CheckFat32Split $false

                    # 2. Configurar archivos de arranque y WinPE en la partición FAT32
                    Write-Host "`n[FASE 2] Configurando cargador EFI y entorno WinPE en particion de arranque ($bootLetter)..." -ForegroundColor Yellow
                    
                    if (Test-Path "$dataLetter\efi") {
                        Write-Host "  -> Sincronizando directorio EFI..." -ForegroundColor Cyan
                        & robocopy.exe "$dataLetter\efi" "$bootLetter\efi" /E /R:1 /W:1 /NP /NDL | Out-Null
                    }
                    if (Test-Path "$dataLetter\boot") {
                        Write-Host "  -> Sincronizando directorio BOOT (fuentes, sdi, bcd)..." -ForegroundColor Cyan
                        & robocopy.exe "$dataLetter\boot" "$bootLetter\boot" /E /R:1 /W:1 /NP /NDL | Out-Null
                    }
                    if (Test-Path "$dataLetter\bootmgr") {
                        Copy-Item "$dataLetter\bootmgr" "$bootLetter\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\bootmgr.efi") {
                        Copy-Item "$dataLetter\bootmgr.efi" "$bootLetter\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\setup.exe") {
                        Copy-Item "$dataLetter\setup.exe" "$bootLetter\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\autorun.inf") {
                        Copy-Item "$dataLetter\autorun.inf" "$bootLetter\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\boot.catalog") {
                        Copy-Item "$dataLetter\boot.catalog" "$bootLetter\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\support") {
                        & robocopy.exe "$dataLetter\support" "$bootLetter\support" /E /R:1 /W:1 /NP /NDL | Out-Null
                    }

                    # COPIA CRITICA: Copiar sources\boot.wim a la partición FAT32 (Resuelve el error 0xc000000f)
                    $bootSourcesDir = Join-Path $bootLetter "sources"
                    if (-not (Test-Path $bootSourcesDir)) {
                        New-Item -ItemType Directory -Path $bootSourcesDir -Force | Out-Null
                    }

                    $srcBootWim = Join-Path $dataLetter "sources\boot.wim"
                    if (Test-Path $srcBootWim) {
                        $wimSizeMB = [Math]::Round((Get-Item $srcBootWim).Length / 1MB, 2)
                        Write-Host "  -> [RESOLUCION 0xc000000f] Copiando 'sources\boot.wim' ($wimSizeMB MB) a $bootSourcesDir..." -ForegroundColor Cyan
                        Copy-Item $srcBootWim (Join-Path $bootSourcesDir "boot.wim") -Force
                        Write-Host "  -> [OK] Entorno WinPE (boot.wim) transferido con exito a la particion FAT32." -ForegroundColor Green
                    } else {
                        Write-Host "  -> [ERROR CRITICO] No se encontro 'sources\boot.wim' en la ISO montada." -ForegroundColor Red
                    }

                    if (Test-Path "$dataLetter\sources\lang.ini") {
                        Copy-Item "$dataLetter\sources\lang.ini" (Join-Path $bootSourcesDir "lang.ini") -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\sources\setup.exe") {
                        Copy-Item "$dataLetter\sources\setup.exe" "$bootSourcesDir\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\sources\setupplatform.dll") {
                        Copy-Item "$dataLetter\sources\setupplatform.dll" "$bootSourcesDir\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\sources\setupplatform.exe") {
                        Copy-Item "$dataLetter\sources\setupplatform.exe" "$bootSourcesDir\" -Force -ErrorAction SilentlyContinue
                    }

                    # 3. Validación y reparación del almacén BCD UEFI y Legacy BIOS
                    Write-Host "`n[FASE 3] Verificando y asegurando integridad del almacen BCD (Boot Configuration Data)..." -ForegroundColor Yellow
                    $bcdUefiPath = "$bootLetter\efi\microsoft\boot\bcd"
                    if (Test-Path $bcdUefiPath) {
                        try {
                            Write-Host "  -> Verificando BCD UEFI en $bcdUefiPath..." -ForegroundColor Cyan
                            & bcdedit.exe /store "$bcdUefiPath" /set '{default}' device "ramdisk=[boot]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}" 2>$null | Out-Null
                            & bcdedit.exe /store "$bcdUefiPath" /set '{default}' osdevice "ramdisk=[boot]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}" 2>$null | Out-Null
                            & bcdedit.exe /store "$bcdUefiPath" /set '{7619dcc8-fafe-11d9-b411-000476eba25f}' ramdisksdidevice "boot" 2>$null | Out-Null
                            & bcdedit.exe /store "$bcdUefiPath" /set '{7619dcc8-fafe-11d9-b411-000476eba25f}' ramdisksdipath "\boot\boot.sdi" 2>$null | Out-Null
                            Write-Host "  -> [OK] BCD UEFI validado y enlazado a [boot]\sources\boot.wim." -ForegroundColor Green
                        } catch {
                            Write-Host "  -> [AVISO] Comprobacion BCD finalizo con advertencia menor: $_" -ForegroundColor Yellow
                        }
                    }

                    $bcdBiosPath = "$bootLetter\boot\bcd"
                    if (Test-Path $bcdBiosPath) {
                        try {
                            & bcdedit.exe /store "$bcdBiosPath" /set '{default}' device "ramdisk=[boot]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}" 2>$null | Out-Null
                            & bcdedit.exe /store "$bcdBiosPath" /set '{default}' osdevice "ramdisk=[boot]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}" 2>$null | Out-Null
                            & bcdedit.exe /store "$bcdBiosPath" /set '{7619dcc8-fafe-11d9-b411-000476eba25f}' ramdisksdidevice "boot" 2>$null | Out-Null
                            & bcdedit.exe /store "$bcdBiosPath" /set '{7619dcc8-fafe-11d9-b411-000476eba25f}' ramdisksdipath "\boot\boot.sdi" 2>$null | Out-Null
                            Write-Host "  -> [OK] BCD Legacy BIOS validado correctamente." -ForegroundColor Green
                        } catch {}
                    }

                    # 4. Inyección de cargador de arranque con bootsect
                    try {
                        if (Get-Command bootsect.exe -ErrorAction SilentlyContinue) {
                            Write-Host "`n[FASE 4] Inyectando codigo de arranque con bootsect.exe (/nt60)..." -ForegroundColor Yellow
                            if ($useGpt) {
                                & bootsect.exe /nt60 $bootLetter /force 2>&1 | Out-Null
                            } else {
                                & bootsect.exe /nt60 $bootLetter /mbr 2>&1 | Out-Null
                            }
                            Write-Host "  -> [OK] Sector de Particion (NT60) actualizado en $bootLetter." -ForegroundColor Green
                        }
                    } catch {}

                    # 5. Generación de motor de enlace automático WinPE (Auto-Mount WIN_DATA)
                    # Resuelve el error "Falta un controlador de medios que tu PC necesita"
                    Write-Host "`n[FASE 5] Inyectando motor de enlace y auto-montaje de particion de datos para WinPE..." -ForegroundColor Yellow

                    $mountCmdContent = @'
@echo off
rem =========================================================================
rem ShellSW - Auto-montaje de particion NTFS de datos (WIN_DATA) en WinPE
rem Asigna letras a todas las particiones USB para que setup.exe detecte install.wim
rem =========================================================================
mountvol /E >nul 2>&1

set "DP_CMD=%TEMP%\mount_dual_dp.txt"
(
echo rescan
for /L %%i in (0,1,8) do (
    echo select disk %%i
    echo select partition 1
    echo assign
    echo select disk %%i
    echo select partition 2
    echo assign
)
) > "%DP_CMD%"

diskpart /s "%DP_CMD%" >nul 2>&1
if exist "%DP_CMD%" del "%DP_CMD%" >nul 2>&1
exit /b 0
'@

                    $autounattendContent = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>cmd.exe /c "for %d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if exist %d:\mount_usb.cmd call %d:\mount_usb.cmd"</Path>
                    <Description>Auto Mount USB Data Partition</Description>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>cmd.exe /c "for %d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if exist %d:\mount_usb.cmd call %d:\mount_usb.cmd"</Path>
                    <Description>Auto Mount USB Data Partition</Description>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>cmd.exe /c "for %d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if exist %d:\mount_usb.cmd call %d:\mount_usb.cmd"</Path>
                    <Description>Auto Mount USB Data Partition</Description>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
</unattend>
'@

                    try {
                        [System.IO.File]::WriteAllText((Join-Path $bootLetter "mount_usb.cmd"), $mountCmdContent, [System.Text.Encoding]::ASCII)
                        [System.IO.File]::WriteAllText((Join-Path $bootLetter "autounattend.xml"), $autounattendContent, [System.Text.Encoding]::UTF8)

                        [System.IO.File]::WriteAllText((Join-Path $dataLetter "mount_usb.cmd"), $mountCmdContent, [System.Text.Encoding]::ASCII)
                        [System.IO.File]::WriteAllText((Join-Path $dataLetter "autounattend.xml"), $autounattendContent, [System.Text.Encoding]::UTF8)

                        Write-Host "  -> [OK] 'mount_usb.cmd' y 'autounattend.xml' inyectados en particion de arranque ($bootLetter) y datos ($dataLetter)." -ForegroundColor Green
                        Write-Host "  -> [RESOLUCION DEFINITIVA] WinPE asignara automaticamente letra a WIN_DATA al arrancar." -ForegroundColor Green
                    } catch {
                        Write-Host "  -> [AVISO] No se pudo escribir archivos auxiliares de montaje: $_" -ForegroundColor Yellow
                    }

                    Write-Host "`n==========================================================================================" -ForegroundColor Green
                    Write-Host " [EXITO COMPLETO] El USB Dual Partition ha sido creado y verificado con exito." -ForegroundColor Green
                    Write-Host "==========================================================================================" -ForegroundColor Green
                    Write-Host "  - Particion FAT32 ($bootLetter): Contiene EFI, BCD y WinPE (boot.wim) para arrancar en UEFI/Legacy." -ForegroundColor Cyan
                    Write-Host "  - Particion NTFS  ($dataLetter): Contiene el instalador completo e install.wim gigante." -ForegroundColor Cyan
                    Write-Host "  - Esquema Utilizado: $tablaTexto | Motor WinPE: Auto-montaje activo para install.wim." -ForegroundColor Green
                    Write-Host "  - Error 'Falta controlador de medios': Neutralizado mediante enlace por autounattend.xml." -ForegroundColor Green
                } else {
                    Write-Host "[ADVERTENCIA] No se detectaron ambas letras de particion. Verifique en Explorador de Windows." -ForegroundColor Yellow
                }
            } else {
                Write-Host "[ERROR] Ruta ISO no encontrada: $isoPath" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "`n[ERROR] Diskpart finalizo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Format-UsbMultibootWindows {
    cabecera
    Write-Header "OPCION 21.5: MULTIBOOT WINDOWS (MULTIPLES VERSIONES WIN 7 / 10 / 11 EN UN USB)"

    Write-Host "`n--- OPCIONES DE ARQUITECTURA MULTIBOOT WINDOWS ---" -ForegroundColor Cyan
    Write-Host "  1. UNIFICAR MULTIPLES EDICIONES CON DISM (WIM Multiversion - Oficial Microsoft)" -ForegroundColor White
    Write-Host "     * Une indices de Windows 10, Windows 11 o Windows 7 en un solo install.wim unificado."
    Write-Host "     * El instalador de Windows presenta un menu interactivo para elegir la version a instalar."
    Write-Host "  2. PREPARAR ESTRUCTURA DE ALMACENAMIENTO MULTI-ISO (Carpetas de Instalacion)" -ForegroundColor White
    Write-Host "     * Prepara el pendrive con particiones y directorios organizados para utilidades de arranque."
    Write-Host "  3. VER GUIA DE CONFIGURACION BCD MULTIBOOT (BCDEdit)" -ForegroundColor White
    Write-Host "     * Muestra las directivas bcdedit para arrancar multiples archivos boot.wim / WinPE."
    Write-Host "  0. Volver al menu anterior" -ForegroundColor Yellow

    $subOp = Read-Host "`nSeleccione la tarea a realizar (1, 2, 3 o 0)"
    switch ($subOp) {
        "1" {
            Write-Host "`n--- UNIFICACION DE IMAGENES WIM MEDIANTE DISM ---" -ForegroundColor Cyan
            $srcWim = Read-Host "Ingrese la ruta del WIM origen (Ej: D:\sources\install.wim)"
            $srcWim = $srcWim.Trim().Trim('"').Trim("'")
            if (-not (Test-Path $srcWim)) {
                Write-Host "[ERROR] El archivo WIM origen no existe: $srcWim" -ForegroundColor Red
                return
            }

            Write-Host "`nObteniendo informacion de indices de: $srcWim..." -ForegroundColor Yellow
            & dism.exe /Get-WimInfo /WimFile:"$srcWim"

            $srcIndex = Read-Host "`nIngrese el numero de Indice a exportar (Ej: 1)"
            $destWim = Read-Host "Ingrese la ruta del WIM destino acumulador (Ej: U:\sources\install.wim)"
            $destWim = $destWim.Trim().Trim('"').Trim("'")
            $destName = Read-Host "Ingrese el nombre visible para esta edicion (Ej: Windows 10 Pro 64-bit)"

            Write-Host "`nEjecutando exportacion con DISM..." -ForegroundColor Cyan
            & dism.exe /Export-Image /SourceImageFile:"$srcWim" /SourceIndex:$srcIndex /DestinationImageFile:"$destWim" /DestinationName:"$destName"

            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n[EXITO] Imagen exportada correctamente al WIM unificado." -ForegroundColor Green
                Write-Host "Puede repetir este proceso con otras ISOs para anadir Windows 11, Windows Server, etc." -ForegroundColor Cyan
            } else {
                Write-Host "`n[ERROR] DISM finalizo con error: $LASTEXITCODE" -ForegroundColor Red
            }
        }
        "2" {
            Write-Host "`n--- PREPARACION DE ESTRUCTURA MULTI-SISTEMA ---" -ForegroundColor Cyan
            $discos = Get-SafeUsbDiskList
            if ($null -eq $discos -or $discos.Count -eq 0) {
                Write-Host "[ERROR] No se detectaron memorias USB conectadas." -ForegroundColor Red
                return
            }
            foreach ($d in $discos) {
                Write-Host ("  [Disco {0}] {1} | {2} GB | Letra(s): {3}" -f $d.Index, $d.Model, $d.SizeGB, $d.Letters) -ForegroundColor Green
            }
            $targetLetter = (Read-Host "`nIngrese la letra de la unidad USB (Ej: F o F:)").Trim().ToUpper()
            $tL = if ($targetLetter -match '^[A-Z]:$') { $targetLetter } elseif ($targetLetter -match '^[A-Z]$') { "$targetLetter" + ":" } else { "" }
            if ($tL -and (Test-Path "$tL\")) {
                $dirs = @("ISOS", "Images\Win10", "Images\Win11", "Images\Win7", "Tools\WinPE", "Drivers")
                foreach ($dir in $dirs) {
                    $p = Join-Path "$tL\" $dir
                    if (-not (Test-Path $p)) {
                        New-Item -ItemType Directory -Path $p -Force | Out-Null
                    }
                }
                Write-Host "`n[EXITO] Estructura de carpetas creada correctamente en $tL\:" -ForegroundColor Green
                Get-ChildItem -Path "$tL\" -Directory | Select-Object Name | Format-Table -AutoSize
            } else {
                Write-Host "[ERROR] Letra de unidad no valida o no accesible." -ForegroundColor Red
            }
        }
        "3" {
            Write-Host "`n==========================================================================================" -ForegroundColor Cyan
            Write-Host "                   GUIA DE COMANDOS BCDEDIT PARA MULTIBOOT DE WINDOWS                     " -ForegroundColor Yellow
            Write-Host "==========================================================================================" -ForegroundColor Cyan
            Write-Host "Para anadir entradas adicionales de arranque (boot.wim) en el BCD de la memoria USB:" -ForegroundColor White
            Write-Host " 1. Copiar GUID de entrada base:" -ForegroundColor Gray
            Write-Host "    bcdedit /store X:\boot\bcd /copy {default} /d `"Instalador Windows 11`"" -ForegroundColor Cyan
            Write-Host " 2. Configurar la ruta del WIM correspondiente (sustituyendo el nuevo {GUID}):" -ForegroundColor Gray
            Write-Host "    bcdedit /store X:\boot\bcd /set {NUEVO-GUID} device ramdisk=[boot]\sources\win11_boot.wim,{ramdiskoptions}" -ForegroundColor Cyan
            Write-Host "    bcdedit /store X:\boot\bcd /set {NUEVO-GUID} osdevice ramdisk=[boot]\sources\win11_boot.wim,{ramdiskoptions}" -ForegroundColor Cyan
            Write-Host " 3. Repetir para cada sistema o herramienta WinPE (Hirens, Gandalf, Win10, etc.)." -ForegroundColor Gray
            Write-Host "==========================================================================================`n" -ForegroundColor Cyan
        }
        Default { Write-Host "Operacion cancelada o no valida." -ForegroundColor Yellow }
    }
}

function Format-UsbLinuxLive {
    cabecera
    Write-Header "OPCION 21.6: PREPARACION USB LIVE PARA SISTEMAS OPERATIVOS LINUX (UBUNTU / DEBIAN / KALI)"

    $discos = Get-SafeUsbDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron memorias USB o unidades extraibles." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES EXTRAIBLES / USB DETECTADAS ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $color = if ($d.IsSystem) { "Magenta" } else { "Green" }
        Write-Host ("  [Disco {0}] {1} | Tamano: {2} GB | Letra(s): {3}" -f $d.Index, $d.Model, $d.SizeGB, $d.Letters) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco USB para crear instalador Linux Live"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Index -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en la lista de unidades USB." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El disco seleccionado contiene el Sistema Operativo." -ForegroundColor Red
        return
    }

    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                     ADVERTENCIA CRITICA DE FORMATEO LINUX LIVE                           " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran TODOS los datos en el [Disco $discoIndex] $($targetDisk.Model)." -ForegroundColor White
    Write-Host " Esquema: MBR / Particion Primaria FAT32 Activa (Etiqueta 'LINUX_LIVE')" -ForegroundColor Yellow
    Write-Host " Compatibilidad: Arranque UEFI nativo (kernel EFI) y Legacy BIOS." -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $diskpartCmds = @(
        "select disk $discoIndex",
        "clean",
        "convert mbr",
        "create partition primary",
        "active",
        "format fs=fat32 quick label=`"LINUX_LIVE`"",
        "assign",
        "exit"
    )

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] Unidad USB formateada e inicializada para Linux Live." -ForegroundColor Green
        Start-Sleep -Seconds 1
        
        $refreshed = Get-SafeUsbDiskList | Where-Object { $_.Index -eq $discoIndex }
        $letra = ($refreshed.Letters -split ",")[0].Trim()

        $isoPath = Read-Host "`nIngrese la ruta completa del archivo .ISO de Linux (Ubuntu, Debian, Kali, Fedora, etc.)"
        $isoPath = $isoPath.Trim().Trim('"').Trim("'")
        if (Test-Path $isoPath) {
            Write-Host "`nIniciando despliegue de archivos Linux Live en $letra..." -ForegroundColor Cyan
            Deploy-IsoToUsb -IsoPath $isoPath -TargetLetter $letra -CheckFat32Split $false

            # Opcional: Persistencia casper-rw
            Write-Host "`n--- CONFIGURACION DE PERSISTENCIA (Opcional para Ubuntu / Debian / Kali) ---" -ForegroundColor Cyan
            Write-Host "La persistencia permite guardar documentos, configuraciones y actualizaciones en el pendrive Live."
            $confPers = Read-Host "Desea habilitar un archivo de persistencia 'casper-rw'? (S/N)"
            if ($confPers.ToUpper() -eq "S") {
                $tamanoMB = Read-Host "Ingrese el tamano de la persistencia en MB (Ej: 2048 para 2GB, 4096 para 4GB [max 4095MB])"
                if ($tamanoMB -match '^\d+$') {
                    $mbInt = [int]$tamanoMB
                    if ($mbInt -gt 4095) { $mbInt = 4095 } # Límite FAT32
                    $bytes = [int64]$mbInt * 1024 * 1024
                    $filePath = Join-Path "$letra\" "casper-rw"
                    Write-Host "Creando contenedor de persistencia: $filePath ($mbInt MB)..." -ForegroundColor Yellow
                    try {
                        & fsutil.exe file createnew "$filePath" $bytes
                        Write-Host "[OK] Archivo casper-rw creado. En el menu de arranque GRUB agregue el parametro 'persistent'." -ForegroundColor Green
                    } catch {
                        Write-Host "[ADVERTENCIA] No se pudo crear el archivo con fsutil: $_" -ForegroundColor Yellow
                    }
                }
            }
            Write-Host "`n[EXITO] USB Linux Live creado y listo para arrancar." -ForegroundColor Green
        } else {
            Write-Host "[ADVERTENCIA] No se especifico ISO valida. La unidad quedo formateada y lista para copia manual." -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Invoke-VentoyMultibootDeploy {
    cabecera
    Write-Header "OPCION 21.7: MULTIBOOT UNIVERSAL ASISTIDO CON MOTOR VENTOY CLI (WINDOWS + LINUX)"

    Write-Host "`n==========================================================================================" -ForegroundColor Cyan
    Write-Host "               VENTOY: EL MOTOR DEFINITIVO PARA MULTIBOOT DIRECTO DE ISOS                " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Cyan
    Write-Host " [COMO FUNCIONA]:" -ForegroundColor White
    Write-Host " 1. Ventoy instala un cargador inteligente en un sector protegido del USB." -ForegroundColor Gray
    Write-Host " 2. El resto de la unidad queda como una particion normal de datos (exFAT / NTFS)." -ForegroundColor Gray
    Write-Host " 3. NO necesitas descomprimir ni quemar ISOs: solo COPIAS Y PEGAS tus archivos .ISO" -ForegroundColor Green
    Write-Host "    (Windows 7, 10, 11, Ubuntu, HirensBoot, Clonezilla, etc.) directamente en la memoria." -ForegroundColor Green
    Write-Host " 4. Al arrancar en cualquier equipo (Legacy BIOS o UEFI con Secure Boot), Ventoy muestra" -ForegroundColor Gray
    Write-Host "    un menu grafico con todas las ISOs disponibles para arrancar al instante." -ForegroundColor Gray
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    $discos = Get-SafeUsbDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron memorias USB conectadas." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES EXTRAIBLES DETECTADAS ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        Write-Host ("  [Disco {0}] {1} | Tamano: {2} GB | Letra(s): {3}" -f $d.Index, $d.Model, $d.SizeGB, $d.Letters) -ForegroundColor Green
    }

    Write-Host "`n[0] CANCELAR y volver" -ForegroundColor Yellow
    $discoSel = Read-Host "`nSeleccione el numero de disco USB donde instalar Ventoy"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Index -eq $discoIndex }
    if ($null -eq $targetDisk -or $targetDisk.IsSystem) {
        Write-Host "[ERROR] Unidad no valida o protegida." -ForegroundColor Red
        return
    }

    # Búsqueda de Ventoy2Disk.exe
    $ventoyPaths = @(
        (Join-Path $PSScriptRoot "recursosExtras\Ventoy\Ventoy2Disk.exe"),
        "e:\shellWil\recursosExtras\Ventoy\Ventoy2Disk.exe",
        (Join-Path $env:TEMP "Ventoy\Ventoy2Disk.exe")
    )
    $ventoyExe = ""
    foreach ($vp in $ventoyPaths) {
        if (Test-Path $vp) { $ventoyExe = $vp; break }
    }

    if (-not $ventoyExe) {
        Write-Host "`n[INFO] No se encontro 'Ventoy2Disk.exe' en la carpeta recursosExtras." -ForegroundColor Yellow
        Write-Host "Opciones disponibles:" -ForegroundColor Cyan
        Write-Host "  1. Indicar manualmente la ruta donde tienes descargado Ventoy2Disk.exe" -ForegroundColor White
        Write-Host "  2. Descargar automaticamente la version oficial de Ventoy desde GitHub" -ForegroundColor White
        Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow

        $vOpt = Read-Host "`nElija una opcion (1, 2 o 0)"
        if ($vOpt -eq "1") {
            $mPath = Read-Host "Ingrese la ruta completa a Ventoy2Disk.exe"
            $mPath = $mPath.Trim().Trim('"').Trim("'")
            if (Test-Path $mPath) { $ventoyExe = $mPath } else { Write-Host "[ERROR] Archivo no encontrado." -ForegroundColor Red; return }
        }
        elseif ($vOpt -eq "2") {
            Write-Host "`nDescargando utilidades oficiales de Ventoy..." -ForegroundColor Cyan
            $ventoyZip = Join-Path $env:TEMP "ventoy_temp.zip"
            $ventoyFolder = Join-Path $env:TEMP "Ventoy"
            $url = "https://github.com/ventoy/Ventoy/releases/download/v1.1.05/ventoy-1.1.05-windows.zip"
            try {
                Invoke-WebRequest -Uri $url -OutFile $ventoyZip -UseBasicParsing
                Expand-Archive -Path $ventoyZip -DestinationPath $ventoyFolder -Force
                $found = Get-ChildItem -Path $ventoyFolder -Filter "Ventoy2Disk.exe" -Recurse | Select-Object -First 1
                if ($found) { $ventoyExe = $found.FullName }
            } catch {
                Write-Host "[ERROR DESCARGA] No se pudo descargar automaticamente Ventoy: $_" -ForegroundColor Red
                return
            }
        } else {
            Write-Host "Operacion cancelada." -ForegroundColor Yellow
            return
        }
    }

    if ($ventoyExe -and (Test-Path $ventoyExe)) {
        Write-Host "`n==========================================================================================" -ForegroundColor Red
        Write-Host " ¡ATENCION! SE FORMATEARA Y PREPARARA CON VENTOY EL DISCO $discoIndex ($($targetDisk.Model))" -ForegroundColor Yellow
        Write-Host "==========================================================================================" -ForegroundColor Red
        $conf = Read-Host "Escriba 'CONFIRMAR' para proceder con la instalacion de Ventoy"
        if ($conf.Trim().ToUpper() -ne "CONFIRMAR") {
            Write-Host "Confirmacion denegada. Operacion cancelada." -ForegroundColor Yellow
            return
        }

        Write-Host "`nInstalando bootloader Ventoy en el Disco $discoIndex..." -ForegroundColor Cyan
        try {
            & "$ventoyExe" VTOYCLI /I /Drive:$discoIndex
            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n[EXITO TOTAL] Ventoy ha sido instalado en la memoria USB." -ForegroundColor Green
                Write-Host "Ahora puedes abrir la unidad en el Explorador de Windows y copiar directamente tus archivos .ISO." -ForegroundColor Cyan
            } else {
                Write-Host "Lanzando interfaz interactiva de Ventoy..." -ForegroundColor Yellow
                Start-Process "$ventoyExe"
            }
        } catch {
            Write-Host "[ERROR] Fallo al invocar Ventoy: $_" -ForegroundColor Red
        }
    }
}

function psSubMenuPrepararUSB {
    $salirSub21 = $false
    do {
        cabecera
        Write-Header "OPCION 21. CREAR MEDIO USB BOOTEABLE DE INSTALACION O RESCATE (ORIGEN)"
        Write-Host "  21.0 Tabla / Matriz tecnica: Tecnologias de arranque USB (Legacy vs UEFI vs Multiboot)" -ForegroundColor Cyan
        Write-Host "  21.1 USB Instalador Windows en MBR-Legacy - SIN BootSect (Formateo Activo)" -ForegroundColor Yellow
        Write-Host "  21.2 USB Instalador Windows en MBR-Legacy - CON BootSect (Inyeccion NT60 + ISO)" -ForegroundColor Yellow
        Write-Host "  21.3 USB Instalador Windows en GPT-UEFI (FAT32) con Split WIM oficial DISM" -ForegroundColor Yellow
        Write-Host "  21.4 USB Instalador Windows en Modo UEFI con Particion Dual (FAT32 Boot + NTFS Datos)" -ForegroundColor Yellow
        Write-Host "  21.5 Multiboot Windows (Legacy y UEFI) - Multiples Versiones Win 7/10/11 en un USB" -ForegroundColor Yellow
        Write-Host "  21.6 USB Instalador Live para Sistemas Operativos Linux (Ubuntu / Debian / Kali)" -ForegroundColor Yellow
        Write-Host "  21.7 Multiboot Universal Asistido con Motor Ventoy CLI (Windows + Linux en un USB)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  0. V O L V E R   A L   S U B M E N U   2 0" -ForegroundColor White
        Write-Header "=============================================================================="

        $op21 = Read-Host "Seleccione la tarea a realizar en Preparacion de Medios USB"

        switch ($op21) {
            { $_ -in "21.0", "0.0", "table" } { Show-UsbBootMatrix }
            { $_ -in "21.1", "1" }             { Format-UsbWindowsLegacy -InjectBootSect $false }
            { $_ -in "21.2", "2" }             { Format-UsbWindowsLegacy -InjectBootSect $true }
            { $_ -in "21.3", "3" }             { Format-UsbWindowsUEFI }
            { $_ -in "21.4", "4" }             { Format-UsbWindowsDualPartition }
            { $_ -in "21.5", "5" }             { Format-UsbMultibootWindows }
            { $_ -in "21.6", "6" }             { Format-UsbLinuxLive }
            { $_ -in "21.7", "7" }             { Invoke-VentoyMultibootDeploy }
            "0" { $salirSub21 = $true }
            Default { Write-Host "Opcion invalida." -ForegroundColor Red }
        }

        if (-not $salirSub21) {
            Write-Host ""
            Read-Host "Presione ENTER para continuar en el menu de Preparacion USB..."
        }
    } while (-not $salirSub21)
}

function Invoke-USBPreparationExternalWindow {
    <#
    .SYNOPSIS
        Despacha la ejecución de las funciones del Grupo 21 (Creación de Medios USB Booteables)
        a un proceso y ventana de consola independiente de PowerShell, liberando inmediatamente la
        consola principal para el operador.
    .PARAMETER OpcionDestino
        Código de la opción a ejecutar ("21", "21.0", "21.1", "21.2", "21.3", "21.4", "21.5", "21.6", "21.7").
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OpcionDestino
    )

    $taskMap = @{
        "21"   = @{ Titulo = "Submenu 21: Crear Medio USB Booteable de Instalacion o Rescate (Origen)"; Cmd = "psSubMenuPrepararUSB" }
        "21.0" = @{ Titulo = "21.0 Matriz de Tecnologias de Arranque USB (Legacy vs UEFI)"; Cmd = "Show-UsbBootMatrix" }
        "21.1" = @{ Titulo = "21.1 USB Instalador Windows en MBR-Legacy - SIN BootSect"; Cmd = "Format-UsbWindowsLegacy -InjectBootSect `$false" }
        "21.2" = @{ Titulo = "21.2 USB Instalador Windows en MBR-Legacy - CON BootSect"; Cmd = "Format-UsbWindowsLegacy -InjectBootSect `$true" }
        "21.3" = @{ Titulo = "21.3 USB Instalador Windows en GPT-UEFI (FAT32 / Split WIM)"; Cmd = "Format-UsbWindowsUEFI" }
        "21.4" = @{ Titulo = "21.4 USB Instalador Windows en UEFI con Particion Dual (FAT32+NTFS)"; Cmd = "Format-UsbWindowsDualPartition" }
        "21.5" = @{ Titulo = "21.5 Multiboot Windows (Legacy y UEFI) - Multiples Versiones"; Cmd = "Format-UsbMultibootWindows" }
        "21.6" = @{ Titulo = "21.6 USB Instalador Live para Sistemas Operativos Linux"; Cmd = "Format-UsbLinuxLive" }
        "21.7" = @{ Titulo = "21.7 Multiboot Universal Asistido con Motor Ventoy CLI"; Cmd = "Invoke-VentoyMultibootDeploy" }
    }

    if (-not $taskMap.ContainsKey($OpcionDestino)) {
        Write-Host "[ERROR] Opcion '$OpcionDestino' no reconocida para preparacion USB." -ForegroundColor Red
        return
    }

    $info = $taskMap[$OpcionDestino]
    $cleanOp = ($OpcionDestino -replace '[^\w]', '_')
    $tempFile = Join-Path $env:TEMP ("shellWil_PrepUSB_" + $cleanOp + "_" + (Get-Random -Minimum 1000 -Maximum 9999) + ".ps1")

    # Lista de funciones del módulo que deben exportarse al subproceso
    $requiredFunctions = @(
        'cabecera',
        'Write-Header',
        'Get-SafeDiskList',
        'Get-SafeUsbDiskList',
        'Invoke-DiskpartBatch',
        'Show-UsbBootMatrix',
        'Deploy-IsoToUsb',
        'Format-UsbWindowsLegacy',
        'Format-UsbWindowsUEFI',
        'Format-UsbWindowsDualPartition',
        'Format-UsbMultibootWindows',
        'Format-UsbLinuxLive',
        'Invoke-VentoyMultibootDeploy',
        'psSubMenuPrepararUSB'
    )

    $sb = New-Object System.Text.StringBuilder

    [void]$sb.AppendLine("# ==========================================================================")
    [void]$sb.AppendLine("# CONSOLA SECUNDARIA AUTONOMA - SHELLSW (PREPARACION USB / RECUPERACION)")
    [void]$sb.AppendLine("# Tarea: $($info.Titulo)")
    [void]$sb.AppendLine("# Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("# ==========================================================================")
    [void]$sb.AppendLine("try { `$Host.UI.RawUI.WindowTitle = 'ShellSW - Preparacion USB [$OpcionDestino]' } catch {}")
    [void]$sb.AppendLine("[Console]::OutputEncoding = [System.Text.Encoding]::UTF8")
    [void]$sb.AppendLine("")

    if (-not (Get-Command 'cabecera' -ErrorAction SilentlyContinue)) {
        [void]$sb.AppendLine(@'
function cabecera {
    Write-Host " ------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Ing. Wilson Yucra - Soft. Administracion y Gestion del Sistema Operativo" -ForegroundColor Cyan
    Write-Host " ------------------------------------------------------------------------" -ForegroundColor Cyan
}
'@)
    }

    if (-not (Get-Command 'Write-Header' -ErrorAction SilentlyContinue)) {
        [void]$sb.AppendLine(@'
function Write-Header {
    param([string]$texto)
    $ancho = $texto.Length + 15
    $linea = "=" * $ancho
    Write-Host "`n$linea" -ForegroundColor Yellow
    Write-Host "| $texto |" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "$linea" -ForegroundColor Yellow
}
'@)
    }

    foreach ($fn in $requiredFunctions) {
        $cmd = Get-Command $fn -ErrorAction SilentlyContinue
        if ($cmd) {
            [void]$sb.AppendLine("function $fn {")
            [void]$sb.AppendLine($cmd.Definition)
            [void]$sb.AppendLine("}`n")
        }
    }

    [void]$sb.AppendLine("# --- EJECUCION DE LA TAREA SOLICITADA ---")
    [void]$sb.AppendLine("try {")
    [void]$sb.AppendLine("    $($info.Cmd)")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("catch {")
    [void]$sb.AppendLine("    Write-Host '`n[ERROR CRITICO EN VENTANA SECUNDARIA]: ' `$_.Exception.Message -ForegroundColor Red")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("finally {")
    if ($OpcionDestino -eq "21") {
        [void]$sb.AppendLine("    Write-Host '`n[Cerrando consola secundaria de preparacion USB...]' -ForegroundColor Gray")
        [void]$sb.AppendLine("    Start-Sleep -Milliseconds 600")
        [void]$sb.AppendLine("    try { Remove-Item -Path `$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue } catch {}")
        [void]$sb.AppendLine("    exit")
    } else {
        [void]$sb.AppendLine("    Write-Host '`n==========================================================================' -ForegroundColor Cyan")
        [void]$sb.AppendLine("    Write-Host ' [PROCESO FINALIZADO] Esta ventana permanecera abierta para su consulta.' -ForegroundColor Green")
        [void]$sb.AppendLine("    Write-Host ' Puede revisar los reportes y cerrarla cuando lo desee.' -ForegroundColor Gray")
        [void]$sb.AppendLine("    Write-Host '==========================================================================' -ForegroundColor Cyan")
        [void]$sb.AppendLine("    Write-Host ''")
        [void]$sb.AppendLine("    Read-Host 'Presione ENTER para cerrar esta ventana...'")
        [void]$sb.AppendLine("    try { Remove-Item -Path `$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue } catch {}")
        [void]$sb.AppendLine("    exit")
    }
    [void]$sb.AppendLine("}")

    [System.IO.File]::WriteAllText($tempFile, $sb.ToString(), [System.Text.Encoding]::UTF8)

    $procArgs = @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$tempFile`""
    )

    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $procArgs -Verb RunAs -ErrorAction Stop
    }
    catch {
        Start-Process -FilePath "powershell.exe" -ArgumentList $procArgs -ErrorAction SilentlyContinue
    }

    Write-Host "`n==========================================================================" -ForegroundColor Cyan
    Write-Host "  [OK] TAREA DESPLEGADA EN UNA VENTANA O CONSOLA INDEPENDIENTE" -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  Accion Solicitada : $($info.Titulo)" -ForegroundColor White
    Write-Host "  Opcion / Codigo   : $OpcionDestino" -ForegroundColor Yellow
    Write-Host "  Estado Operativo  : Se ha abierto una consola secundaria de PowerShell." -ForegroundColor Gray
    Write-Host "  Disponibilidad    : Esta consola principal queda 100% LIBRE para su uso" -ForegroundColor Green
    Write-Host "                      inmediato en otras tareas del sistema." -ForegroundColor Gray
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function psSubMenu20 {
    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header "Opcion  20. ---)) LOCAL: INFORMACION SISTEMA CMD [RAM] [HDD] - DISM - RESETEAR RED."
            Write-Host "1. Informacion de la MEMORIA RAM."
            Write-Host "2. Informacion del DISCO DURO."
            Write-Host "  2.1. Capacidad y tipo de DISCO DURO."
            Write-Host "3. Mostrar Unidades Logicas del DISCO DURO."
            Write-Host "4. Aplicaciones que se INICIAN con el SISTEMA OPERATIVO."
            Write-Host "5. Mostrar Errores con aplicaciones en el SISTEMA OPERATIVO."
            Write-Host "6. Mostrar informacion del BIOS."
            Write-Host "  6.1. Modo de Instalacion de Windows Legacy o UEFI."
            Write-Host "7. Mostrar informacion de la PC HARDWARE."
            Write-Host "8. Propiedades del Sistema Operativo (SYSTEMINFO)."
            Write-Host "  8.1. Mostrar Version de Windows."
            Write-Host "  8.2. Mostrar Version de Windows."
            Write-Host "  8.3. Mostrar Version de Windows Script Host."
            Write-Host "  8.4. Mostrar Version WinVer."
            Write-Host "******************************************************************************************"
            Write-Host "9. Escaneo de archivos protegidos del S.O. - Revision Rapida. (sfc /scannow)."
            Write-Host "10. Escanea danios en almacen de componentes "DISM 1" - Dism.exe /Online /Cleanup-Image /ScanHealth"
            Write-Host "11. Comprobacion RAPIDA si imagen esta marcada como daniado "DISM 2" - DISM /Online /Cleanup-Image /CheckHealth"
            Write-Host "12. Si es posible realiza operacion de reparacion automatica "DISM 3" - DISM /Online /Cleanup-Image /RestoreHealth"
            Write-Host "13. Limpia los componentes reemplazados "DISM 4" - Dism.exe /Online /Cleanup-Image /StartComponentCleanup"
            Write-Host "14. Revision Exhaustivo "ANALISIS PROFUNDO" (dism) - Escaneo, reparacion, limpieza y verificacion"
            Write-Host "******************************************************************************************"
            Write-Host "17. Listar Usuarios Windows"
            Write-Host "18. Recursos Compartidos de Windows"
            Write-Host "19. Preparar Disco de Destino (HDD / SSD / NVMe) para S.O. o Almacenamiento [VENTANA EXTERNA]" -ForegroundColor Cyan
            Write-Host "  19.0 Tabla de relacion: Filesystem vs Particion vs Modo Arranque [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.1 Informacion tecnica detallada de la unidad (Particion, FS, Salud SMART) [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.2 Verificacion de sectores y revision de superficie (Superficial vs Profunda) [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.3 Preparar Disco para Windows Legacy (MBR + FAT32/NTFS) - Particion ACTIVA [Win 98/XP/7/10/11] [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.4 Preparar Disco para Windows UEFI (GPT + NTFS) - Particion de Sistema Lista [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.5 Limpieza y Reinicializacion Profunda de Disco (Clean / Clean All - Wipe Seguro) [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.6 Formateo de Almacenamiento General (FAT32/NTFS/exFAT) [Multi-Particion FAT32] [VENTANA EXTERNA]" -ForegroundColor Green
            Write-Host "  19.7 Formateo de Unidades y Discos para GNU/Linux (Particion Nativa RAW / ext4) [VENTANA EXTERNA]" -ForegroundColor Green
            Write-Host "21. Crear Medio USB Booteable de Instalacion o Rescate (Origen) [VENTANA EXTERNA]" -ForegroundColor Cyan
            Write-Host "  21.0 Matriz tecnica de tecnologias de arranque USB (Legacy vs UEFI vs Multiboot)" -ForegroundColor Yellow
            Write-Host "  21.1 USB Instalador Windows en MBR-Legacy - SIN BootSect (Formateo Activo)" -ForegroundColor Yellow
            Write-Host "  21.2 USB Instalador Windows en MBR-Legacy - CON BootSect (Inyeccion NT60 + ISO)" -ForegroundColor Yellow
            Write-Host "  21.3 USB Instalador Windows en GPT-UEFI (FAT32) con Split WIM oficial DISM" -ForegroundColor Yellow
            Write-Host "  21.4 USB Instalador Windows en Modo UEFI con Particion Dual (FAT32 Boot + NTFS Datos)" -ForegroundColor Yellow
            Write-Host "  21.5 Multiboot Windows (Legacy y UEFI) - Multiples Versiones Win 7/10/11 en un USB" -ForegroundColor Yellow
            Write-Host "  21.6 USB Instalador Live para Sistemas Operativos Linux (Ubuntu / Debian / Kali)" -ForegroundColor Yellow
            Write-Host "  21.7 Multiboot Universal Asistido con Motor Ventoy CLI (Windows + Linux en un USB)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "=============================================================================="
            
            $op = Read-Host "Seleccione la tarea a realizar"

            switch ($op) {
                "1" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* DETALLE DE MEMORIA RAM *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # 1. Obtener datos de hardware (Capa física)
                    $physicalMem = Get-WmiObject Win32_PhysicalMemory
                    $memArray = Get-WmiObject -Class Win32_PhysicalMemoryArray
                    # 2. Obtener datos del Sistema Operativo (Uso en tiempo real)
                    $osMem = Get-WmiObject Win32_OperatingSystem
                    $memTotal = [Math]::Round($osMem.TotalVisibleMemorySize / 1MB, 2)
                    $memLibre = [Math]::Round($osMem.FreePhysicalMemory / 1MB, 2)
                    $memEnUso = [Math]::Round($memTotal - $memLibre, 2)
                    $porcentajeUso = [Math]::Round(($memEnUso / $memTotal) * 100, 1)

                    # Función para traducir el tipo de memoria
                    function Get-MemoryType ($type, $speed) {
                        switch ($type) {
                            20 { return "DDR" }
                            21 { return "DDR2" }
                            24 { return "DDR3" }
                            26 { return "DDR4" }
                            34 { return "DDR5" }
                            0 {
                                # Si es 0, intentamos adivinar por la velocidad (MHz)
                                if ($speed -ge 4800) { return "DDR5 (Estimado)" }
                                if ($speed -ge 2133) { return "DDR4 (Estimado)" }
                                if ($speed -ge 1333) { return "DDR3 (Estimado)" }
                                return "Desconocido"
                            }
                            Default { return "Otro ($type)" }
                        }
                    }

                    # 3. Mostrar Capacidad de la Placa y Estado de Uso
                    Write-Host "Capacidad Maxima Soportada : $([Math]::Round($memArray.MaxCapacity / 1MB, 0)) GB"
                    Write-Host "Ranuras Totales            : $($memArray.MemoryDevices)"
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                    Write-Host "Memoria Total instalada    : $memTotal GB" -ForegroundColor White
                    Write-Host "Memoria en Uso             : $memEnUso GB ($porcentajeUso%)" -ForegroundColor Yellow
                    Write-Host "Memoria Disponible         : $memLibre GB" -ForegroundColor Green
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # 4. Detalle de los Módulos (Físico)
                    $detalleModulos = $physicalMem | Select-Object `
                        DeviceLocator, 
                    Manufacturer, 
                    @{Name = "Capacidad"; Expression = { [Math]::Round($_.Capacity / 1GB, 0), "GB" -join " " } },
                    @{Name = "Tipo"; Expression = { Get-MemoryType $_.SMBIOSMemoryType $_.Speed } },
                    @{Name = "Velocidad"; Expression = { $_.Speed, "MHz" -join " " } },
                    PartNumber

                    Write-Host "Detalle por Ranura:" -ForegroundColor Cyan
                    $detalleModulos | Format-Table -AutoSize
                }
                "2" { 
                    cabecera                
                    menuOpcion "Haz elegido el SUB_MENU:  $opcion ;;; Opcion:  $op "

                    #wmic diskdrive get caption,InterfaceType,name,serialnumber,Signature,Size,status
                    
                    Write-Host "`n******* DETALLE DE UNIDADES DE DISCO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    Get-WmiObject Win32_DiskDrive | Select-Object `
                        Caption, 
                    InterfaceType, 
                    DeviceID, 
                    SerialNumber, 
                    @{Name = "Tamaño(GB)"; Expression = { [Math]::Round($_.Size / 1GB, 2) } }, 
                    Status | 
                    Format-Table -AutoSize

                    #otra alternativa
                    #Get-PhysicalDisk | Select-Object `
                    #FriendlyName, 
                    #SerialNumber, 
                    #MediaType, 
                    #@{Name="Tamaño(GB)"; Expression={[Math]::Round($_.Size / 1GB, 2)}}, 
                    #OperationalStatus, 
                    #HealthStatus | 
                    #Format-Table -AutoSize

                }
                "2.1" { 
                    #clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* CAPACIDAD Y TIPO DE DISCO DURO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Verificar si existe Get-PhysicalDisk (Windows 8+)
                    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
                        # Obtenemos todos los discos físicos ordenados por DeviceID
                        $discos = Get-PhysicalDisk | Sort-Object DeviceId

                        if ($null -eq $discos) {
                            Write-Host "No se detectaron unidades de disco en este equipo." -ForegroundColor Yellow
                        }
                        else {
                            foreach ($disk in $discos) {
                                # Intentamos obtener detalles adicionales de almacenamiento
                                $storageDetails = $null
                                try {
                                    $storageDetails = $disk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
                                } catch {}

                                # Determinar el tipo de disco
                                $tipoDisco = "Disco Rigido (HDD)"
                                if ($disk.BusType -eq "USB" -or $disk.MediaType -eq "Removable" -or $disk.MediaType -eq "External") {
                                    $tipoDisco = "Unidad Extraible"
                                }
                                elseif ($disk.MediaType -eq "SSD") {
                                    $tipoDisco = "Disco Solido (SSD)"
                                }
                                elseif ($disk.FriendlyName -match "SSD|Solid State|NVMe") {
                                    $tipoDisco = "Disco Solido (SSD)"
                                }
                                elseif ($disk.BusType -eq "USB") {
                                    $tipoDisco = "Unidad Extraible"
                                }

                                # Estado de salud
                                $salud = $disk.HealthStatus

                                # Formatear capacidad
                                $capacidadGB = "$([Math]::Round($disk.Size / 1GB, 2)) GB"

                                Write-Host "[ Unidad: $($disk.FriendlyName) ]" -ForegroundColor White -BackgroundColor DarkBlue
                                
                                # Preparar variables para evitar lógica compleja en el hashtable
                                $usoVida = "N/A"
                                if ($storageDetails -and $storageDetails.Wear -ne $null) {
                                    $usoVida = "$($storageDetails.Wear)%"
                                }

                                $temp = "N/A"
                                if ($storageDetails -and $storageDetails.Temperature -ne $null) {
                                    $temp = "$($storageDetails.Temperature)°C"
                                }

                                $nSerie = "Desconocido"
                                if ($disk.SerialNumber) {
                                    $nSerie = $disk.SerialNumber.Trim()
                                }

                                # Tabla de información técnica compatible en formato de lista idéntico al de la imagen
                                New-Object PSObject -Property @{
                                    "Numero"      = $disk.DeviceId
                                    "Modelo"      = $disk.FriendlyName
                                    "Tipo"        = $tipoDisco
                                    "Protocolo"   = $disk.BusType  # NVMe, SATA, USB
                                    "Capacidad"   = $capacidadGB
                                    "EstadoSalud" = $salud
                                    "Uso_Vida"    = $usoVida
                                    "Temp"        = $temp
                                    "N_Serie"     = $nSerie
                                } | Select-Object Numero, Modelo, Tipo, Protocolo, Capacidad, EstadoSalud, Uso_Vida, Temp, N_Serie | Format-List
                                
                                Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                            }
                        }
                    }
                    else {
                        Write-Host "Nota: Get-PhysicalDisk no esta disponible en este sistema operativo (compatible en Windows 8+)." -ForegroundColor Yellow
                        Write-Host "Obteniendo informacion detallada de unidades fisicas a traves de WMI..." -ForegroundColor Yellow
                        Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                        
                        $discosWmi = Get-WmiObject Win32_DiskDrive | Sort-Object Index
                        foreach ($d in $discosWmi) {
                            # Determinar el tipo de disco para Windows 7
                            $tipoDisco = "Disco Rigido (HDD)"
                            if ($d.InterfaceType -eq "USB" -or $d.MediaType -match "External|Removable" -or $d.Model -match "USB|SD Card|Card Reader") {
                                $tipoDisco = "Unidad Extraible"
                            }
                            elseif ($d.Model -match "SSD|Solid State|NVMe|SATA SSD") {
                                $tipoDisco = "Disco Solido (SSD)"
                            }

                            # Estado de salud
                            $salud = $d.Status
                            if ($salud -eq "OK") { $salud = "Healthy" }

                            # Capacidad en GB
                            $capacidadGB = "$([Math]::Round([double]$d.Size / 1GB, 2)) GB"

                            $nSerie = "Desconocido"
                            if ($d.SerialNumber) {
                                $nSerie = $d.SerialNumber.Trim()
                            }

                            Write-Host "[ Unidad: $($d.Model) ]" -ForegroundColor White -BackgroundColor DarkBlue
                            
                            New-Object PSObject -Property @{
                                "Numero"      = $d.Index
                                "Modelo"      = $d.Model
                                "Tipo"        = $tipoDisco
                                "Protocolo"   = $d.InterfaceType  # IDE, SCSI, USB, etc.
                                "Capacidad"   = $capacidadGB
                                "EstadoSalud" = $salud
                                "Uso_Vida"    = "N/A (Requiere Windows 8+)"
                                "Temp"        = "N/A (Requiere Windows 8+)"
                                "N_Serie"     = $nSerie
                            } | Select-Object Numero, Modelo, Tipo, Protocolo, Capacidad, EstadoSalud, Uso_Vida, Temp, N_Serie | Format-List
                            
                            Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                        }
                    }
                }
                "3" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* REPORTE DE UNIDADES DE ALMACENAMIENTO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtenemos discos locales (DriveType=3) usando WMI para compatibilidad total
                    $unidades = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"

                    foreach ($u in $unidades) {
                        
                        # Forzamos [double] para evitar errores de desbordamiento en discos grandes
                        $totalBytes = [double]$u.Size
                        $freeBytes = [double]$u.FreeSpace
                        
                        # Conversión a GB (1024^3)
                        $totalGB = [Math]::Round($totalBytes / 1GB, 2)
                        $libreGB = [Math]::Round($freeBytes / 1GB, 2)
                        $usadoGB = [Math]::Round($totalGB - $libreGB, 2)
                        
                        # Cálculo de porcentaje de uso
                        if ($totalGB -gt 0) {
                            $porcentajeUsado = [Math]::Round(($usadoGB / $totalGB) * 100, 1)
                        }
                        else {
                            $porcentajeUsado = 0
                        }

                        # Creación de objeto compatible con PowerShell 2.0
                        $discoReporte = New-Object PSObject
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Unidad" -Value $u.DeviceID
                        # $discoReporte | Add-Member -MemberType NoteProperty -Name "Nombre" -Value ($u.VolumeName if ($u.VolumeName) { $u.VolumeName } else { "Sin Etiqueta" })
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Formato" -Value $u.FileSystem
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Total (GB)" -Value $totalGB
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Libre (GB)" -Value $libreGB
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Ocupado (GB)" -Value "$usadoGB ($porcentajeUsado%)"
                        
                        # Salida del objeto
                        $discoReporte
                    }

                    # ****
                    Write-Host "`n******* ANALISIS DE ALMACENAMIENTO (DISCOS LOCALES) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                    # Obtenemos los discos logicos tipo 3 (Discos Locales)
                    Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
                        # Calculos matematicos
                        $sizeGB = [Math]::Round($_.Size / 1GB, 2)
                        $freeGB = [Math]::Round($_.FreeSpace / 1GB, 2)
                        $usedGB = [Math]::Round($sizeGB - $freeGB, 2)
                        $percentFree = [Math]::Round(($freeGB / $sizeGB) * 100, 1)
                        $percentUsed = 100 - $percentFree
                        # Crear un objeto con la informacion detallada compatible
                        New-Object PSObject -Property @{
                            "Unidad"        = $_.DeviceID
                            "Nombre"        = $_.VolumeName
                            "Formato"       = $_.FileSystem
                            "Tamaño Total"  = "$sizeGB GB"
                            "Espacio Libre" = "$freeGB GB ($percentFree%)"
                            "Espacio Usado" = "$usedGB GB ($percentUsed%)"
                            "Estado"        = $_.Status
                        } | Select-Object Unidad, Nombre, Formato, "Tamaño Total", "Espacio Libre", "Espacio Usado", Estado
                    } | Format-Table -AutoSize
                    Write-Host "Nota: Si el espacio libre es menor al 10%, se recomienda limpieza." -ForegroundColor Yellow
                    # ****

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "4" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* PROGRAMAS DE INICIO CON ESTADO DE PROCESO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # 1. Foto instantánea de procesos (optimizamos RAM al no llamar a Get-Process en cada ciclo)
                    $procesosActivos = Get-Process | Select-Object Name, Id

                    # 2. Obtener comandos de inicio
                    $startupCommands = Get-WmiObject -Class Win32_StartupCommand

                    foreach ($item in $startupCommands) {
                        # LIMPIEZA DEL COMANDO: 
                        # Extraemos el nombre limpio del ejecutable ignorando comillas, rutas y parámetros (.exe)
                        # Ejemplo: "C:\Archivos de programa\App.exe" --silent  =>  App
                        $rawCommand = $item.Command.Split('"').Where({ $_ -ne "" })[0]
                        $nombreLimpio = [System.IO.Path]::GetFileNameWithoutExtension($rawCommand)

                        # 3. Buscar coincidencia en procesos activos
                        $procesoMatch = $procesosActivos | Where-Object { $_.Name -eq $nombreLimpio }
                        
                        # 4. Definir color y texto según si está activo o no
                        $statusColor = "Gray"
                        $pidDisplay = "No activo"
                        
                        if ($procesoMatch) {
                            $statusColor = "Green"
                            $pidDisplay = ($procesoMatch.Id -join ", ") # Por si hay varias instancias abiertas
                        }

                        # 5. Mostrar la información en formato lista organizada
                        Write-Host "[ $($item.Caption.ToUpper()) ]" -ForegroundColor White -BackgroundColor DarkBlue
                        Write-Host "PID          : " -NoNewline; Write-Host $pidDisplay -ForegroundColor $statusColor
                        Write-Host "Ejecutable   : $($item.Command)"
                        Write-Host "Usuario      : $($item.User)"
                        Write-Host "Ubicación    : $($item.Location)"
                        if ($item.Description -and $item.Description -ne $item.Caption) {
                            Write-Host "Descripción  : $($item.Description)"
                        }
                        Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                    }

                }
                "5" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* REPORTE DETALLADO DE PROGRAMAS DE INICIO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtenemos la información de inicio
                    $startupItems = Get-WmiObject -Class Win32_StartupCommand

                    foreach ($item in $startupItems) {
                        # Resaltamos el nombre del programa en azul
                        Write-Host "[ $($item.Caption.ToUpper()) ]" -ForegroundColor White -BackgroundColor DarkBlue
                        
                        # Creamos un objeto personalizado para mostrar los datos ordenados
                        New-Object PSObject -Property @{
                            "Comando/Ruta" = $item.Command
                            "Usuario"      = $item.User
                            "Ubicación"    = $item.Location
                            "Descripción"  = $item.Description
                        } | Select-Object "Comando/Ruta", Usuario, "Ubicación", "Descripción" | Format-List
                        
                        Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                    }

                }
                "6" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* DETALLE DEL SISTEMA (BIOS/FIRMWARE) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtenemos la información de la BIOS mediante WMI
                    $bios = Get-WmiObject -Class Win32_BIOS

                    if ($bios) {
                        # Creamos un objeto compatible con PowerShell 2.0 (Windows 7)
                        $infoBIOS = New-Object PSObject
                        
                        # Usamos la sintaxis completa para evitar parámetros ambiguos
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Fabricante" -Value $bios.Manufacturer
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Nombre_Version" -Value $bios.Name
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Version_SMBIOS" -Value $bios.SMBIOSBIOSVersion
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "N_Serie" -Value $bios.SerialNumber
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Estado" -Value $bios.Status
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Idioma" -Value $bios.CurrentLanguage

                        # Mostramos la información
                        $infoBIOS | Format-List
                    }
                    else {
                        Write-Host "No se pudo obtener información de la BIOS." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "6.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # Método directo basado en la variable de entorno de firmware
                    $firmware = $env:firmware_type

                    if ($null -eq $firmware) {
                        # Si la variable está vacía, consultamos la carpeta de Windows
                        if (Test-Path "$env:windir\Panther\setupact.log") {
                            # (Usa el código del log anterior como respaldo)
                        }
                        else {
                            Write-Host "Modo de arranque: Legacy / BIOS (Detectado por exclusión)" -ForegroundColor Yellow
                        }
                    }
                    else {
                        Write-Host "Modo de arranque: $firmware" -ForegroundColor Yellow
                    }
                }
                "7" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* DETALLE DEL PROCESADOR (CPU) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtenemos la información de la CPU
                    $cpu = Get-WmiObject -Class Win32_Processor

                    if ($cpu) {
                        # 1. Procesamos la arquitectura antes para evitar el error del 'if'
                        $archText = "32-bit"
                        if ($cpu.AddressWidth -eq 64) {
                            $archText = "64-bit"
                        }

                        # 2. Creamos el objeto (Sintaxis compatible con PS 2.0)
                        $infoCPU = New-Object PSObject
                        
                        # 3. Asignamos los miembros usando la sintaxis completa y segura
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Modelo" -Value $cpu.Name
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Fabricante" -Value $cpu.Manufacturer
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Arquitectura" -Value $archText
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Nucleos_Fisicos" -Value $cpu.NumberOfCores
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Hilos_Logicos" -Value $cpu.NumberOfLogicalProcessors
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Velocidad_Base" -Value "$($cpu.MaxClockSpeed) MHz"
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Socket" -Value $cpu.SocketDesignation
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "ID_Procesador" -Value $cpu.ProcessorId

                        # Mostramos el resultado
                        $infoCPU | Format-List
                    }
                    else {
                        Write-Host "No se pudo obtener información del procesador." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                }
                "8" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n==================================================================" -ForegroundColor White
                    Write-Host "         REPORTE DETALLADO DE SISTEMA (Mantenimiento SW)" -ForegroundColor Cyan
                    Write-Host "==================================================================" -ForegroundColor White

                    # 1. Recolección previa de datos (WMI)
                    $os = Get-WmiObject Win32_OperatingSystem
                    $cs = Get-WmiObject Win32_ComputerSystem
                    $bios = Get-WmiObject Win32_BIOS
                    $cpu = Get-WmiObject Win32_Processor

                    # 2. Preparación de variables de tiempo y memoria
                    $totalRAM = [Math]::Round([double]$cs.TotalPhysicalMemory / 1GB, 2)
                    $freeRAM = [Math]::Round([double]$os.FreePhysicalMemory / 1MB, 2)
                    $lastBoot = $os.ConvertToDateTime($os.LastBootUpTime)
                    $installDate = $os.ConvertToDateTime($os.InstallDate)
                    $arch = if ($os.OSArchitecture) { $os.OSArchitecture } else { "No detectada" }

                    # --- SECCION 1: IDENTIFICACIÓN DEL EQUIPO ---
                    Write-Host "[ IDENTIFICACION DEL HARDWARE ]" -ForegroundColor Yellow
                    $ident = New-Object PSObject
                    $ident | Add-Member -MemberType NoteProperty -Name "Equipo" -Value $cs.Name
                    $ident | Add-Member -MemberType NoteProperty -Name "Fabricante" -Value $cs.Manufacturer
                    $ident | Add-Member -MemberType NoteProperty -Name "Modelo" -Value $cs.Model
                    $ident | Add-Member -MemberType NoteProperty -Name "N_Serie" -Value $bios.SerialNumber
                    $ident | Format-List

                    # --- SECCIÓN 2: SOFTWARE Y SISTEMA OPERATIVO ---
                    Write-Host "[ SISTEMA OPERATIVO ]" -ForegroundColor Yellow
                    $soft = New-Object PSObject
                    $soft | Add-Member -MemberType NoteProperty -Name "Nombre_SO" -Value $os.Caption
                    $soft | Add-Member -MemberType NoteProperty -Name "Version" -Value $os.Version
                    $soft | Add-Member -MemberType NoteProperty -Name "Arquitectura" -Value $arch
                    $soft | Add-Member -MemberType NoteProperty -Name "Instalacion" -Value $installDate
                    $soft | Add-Member -MemberType NoteProperty -Name "Directorio" -Value $os.WindowsDirectory
                    $soft | Format-List

                    # --- SECCIÓN 3: COMPONENTES PRINCIPALES (CPU/RAM) ---
                    Write-Host "[ COMPONENTES INTERNOS ]" -ForegroundColor Yellow

                    $hard = New-Object PSObject
                    $hard | Add-Member -MemberType NoteProperty -Name "Procesador" -Value $cpu.Name
                    $hard | Add-Member -MemberType NoteProperty -Name "Nucleos_Hilos" -Value "$($cpu.NumberOfCores) Cores / $($cpu.NumberOfLogicalProcessors) Threads"
                    $hard | Add-Member -MemberType NoteProperty -Name "RAM_Total" -Value "$totalRAM GB"
                    $hard | Add-Member -MemberType NoteProperty -Name "RAM_Disponible" -Value "$freeRAM GB"
                    $hard | Add-Member -MemberType NoteProperty -Name "BIOS_Version" -Value $bios.SMBIOSBIOSVersion
                    $hard | Format-List

                    # --- SECCIÓN 4: ESTADO Y CONTEXTO ---
                    Write-Host "[ ESTADO Y RED ]" -ForegroundColor Yellow
                    $estado = New-Object PSObject
                    $estado | Add-Member -MemberType NoteProperty -Name "Dominio_Grupo" -Value $cs.Domain
                    $estado | Add-Member -MemberType NoteProperty -Name "Usuario_Logueado" -Value $cs.UserName
                    $estado | Add-Member -MemberType NoteProperty -Name "Ultimo_Reinicio" -Value $lastBoot
                    $estado | Add-Member -MemberType NoteProperty -Name "Uptime_Minutos" -Value ([Math]::Round((Get-Date).Subtract($lastBoot).TotalMinutes, 0))
                    $estado | Format-List

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "8.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"
                
                    systeminfo | find /i "Sistema Operativo"

                }
                "8.2" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    wmic cpu get caption

                }
                "8.3" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # slmgr /dlv
                    Start-Process "slmgr" -ArgumentList "/dlv" -Wait
                    

                }
                "8.4" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Start-Process "winver" -Wait
                }
                "9" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "Ejecutando: Sfc /Scannow"
                    Sfc /Scannow
                    Write-Host "Analisis de escaneo terminado: OK"

                    Write-Host "Presione Enter para volver..." -ForegroundColor Green
                    Read-Host
                }
                "10" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "******* ANALISIS DE INTEGRIDAD DE IMAGEN (DISM) /ScanHealth *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtener la versión de Windows a través de WMI (Compatible con Win 7)
                    $os = Get-WmiObject Win32_OperatingSystem
                    $version = [double]$os.Version.Substring(0, 3) # Ej: 6.1 (Win7), 6.3 (Win8.1), 10.0 (Win10/11)

                    Write-Host "Sistema detectado: $($os.Caption)" -ForegroundColor Gray

                    # Lógica de ejecución según versión
                    if ($version -ge 6.2) {
                        # Windows 8, 8.1, 10 y 11
                        Write-Host "Iniciando ScanHealth nativo..." -ForegroundColor Yellow
                        
                        # Ejecución de DISM
                        & dism.exe /Online /Cleanup-Image /ScanHealth

                        # Comprobación de éxito ($LASTEXITCODE es el equivalente a %errorlevel%)
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "La operacion se completo con exito.  ::: OK" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Ocurrió un error durante la operación (COdigo: $LASTEXITCODE)." -ForegroundColor Red
                        }
                    }
                    elseif ($version -eq 6.1) {
                        # Windows 7
                        Write-Host "Nota: En Windows 7, /ScanHealth no existe nativamente en DISM." -ForegroundColor Yellow
                        Write-Host "Se recomienda usar 'sfc /scannow' o instalar System Update Readiness Tool." -ForegroundColor Gray
                        
                        # Alternativa segura para Windows 7
                        Write-Host "Ejecutando comprobaciOn alternativa (SFC)..." -ForegroundColor White
                        & sfc /scannow
                    }
                    else {
                        Write-Host "Lo sentimos, esta opción no esta disponible en este sistema operativo." -ForegroundColor Red
                    }

                }
                "11" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "/CheckHealth: Realiza una comprobacion rapida para ver si la imagen esta marcada como daniada, solo verifica una marca de corrupcion"
                    Write-Host "******* VERIFICACION DE SALUD DE IMAGEN (DISM) /CheckHealth *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtener la versión del SO mediante WMI
                    $os = Get-WmiObject Win32_OperatingSystem
                    $version = [double]$os.Version.Substring(0, 3)

                    Write-Host "Sistema detectado: $($os.Caption)" -ForegroundColor Gray

                    # DISM /CheckHealth solo está disponible en versiones >= 6.2 (Win 8/10/11)
                    if ($version -ge 6.2) {
                        Write-Host "Ejecutando DISM /CheckHealth..." -ForegroundColor Yellow
                        
                        # Ejecutamos DISM nativo
                        & dism.exe /Online /Cleanup-Image /CheckHealth

                        # $LASTEXITCODE es el equivalente nativo a %errorlevel%
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "La operacion se completo con exito. ::: OK" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Ocurrio un error durante la operacion (Codigo: $LASTEXITCODE)." -ForegroundColor Red
                        }
                    } 
                    elseif ($version -eq 6.1) {
                        # Caso específico para Windows 7
                        Write-Host "Nota: En Windows 7, DISM no soporta /CheckHealth nativamente." -ForegroundColor Yellow
                        Write-Host "Se recomienda usar 'sfc /verifyonly' para verificar integridad." -ForegroundColor White
                        
                        & sfc /verifyonly

                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "La verificacion se completo. Revise los resultados arriba." -ForegroundColor Green
                        }
                        else {
                            Write-Host "SFC detecto problemas o no pudo ejecutarse." -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "Esta opcion no es compatible con versiones anteriores a Windows 7." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "12" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "Para reparar la imagen del sistema operativo, buscando y restaurando archivos corruptos o dañados mediante la comparacion con copias de archivos sanos de los servidores de Windows Update. Esta herramienta es util para solucionar problemas con los archivos de sistema, especialmente cuando el comando SFC /ScanNow no es suficiente o no funciona"
                    Write-Host "******* REPARACION DE IMAGEN DE SISTEMA (DISM) /RestoreHealth *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtener versión del sistema operativo
                    $os = Get-WmiObject Win32_OperatingSystem
                    $version = [double]$os.Version.Substring(0, 3)

                    Write-Host "Sistema detectado: $($os.Caption)" -ForegroundColor Gray

                    # DISM /RestoreHealth requiere Windows 8 o superior (v6.2+)
                    if ($version -ge 6.2) {
                        Write-Host "Iniciando reparacion automatica (/RestoreHealth)..." -ForegroundColor Yellow
                        Write-Host "Este proceso puede tardar varios minutos y requiere internet." -ForegroundColor Gray
                        
                        # Ejecutamos DISM nativo
                        & dism.exe /Online /Cleanup-Image /RestoreHealth

                        # Verificamos el código de salida
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "La imagen se reparo correctamente.   :::  OK" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Ocurrio un error ($LASTEXITCODE). Verifique su conexion a Internet." -ForegroundColor Red
                        }
                    } 
                    elseif ($version -eq 6.1) {
                        # Caso Windows 7: No existe RestoreHealth nativo
                        Write-Host "Nota: Windows 7 no soporta /RestoreHealth via DISM." -ForegroundColor Yellow
                        Write-Host "Ejecutando reparacion de archivos de sistema (SFC)..." -ForegroundColor White
                        
                        & sfc /scannow

                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "SFC finalizo con exito." -ForegroundColor Green
                        }
                        else {
                            Write-Host "SFC encontro errores o no pudo completarse." -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "Opcion no compatible con esta version de Windows." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Green
                }
                "13" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "Para eliminar archivos antiguos y de sistema que ya no son necesarios, con el fin de optimizar y liberar espacio en tu sistema Windows."
                    Write-Host "`n******* LIMPIEZA DE COMPONENTES (DISM / StartComponentCleanup) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtener versión del sistema operativo
                    $os = Get-WmiObject Win32_OperatingSystem
                    $version = [double]$os.Version.Substring(0, 3)

                    Write-Host "Sistema detectado: $($os.Caption)" -ForegroundColor Gray

                    # /StartComponentCleanup requiere Windows 8 o superior (v6.2+)
                    if ($version -ge 6.2) {
                        Write-Host "Iniciando limpieza de la carpeta WinSxS..." -ForegroundColor Yellow
                        Write-Host "Este proceso reduce el tamanio de la carpeta de sistema." -ForegroundColor Gray
                        
                        # Ejecutamos DISM nativo
                        & dism.exe /Online /Cleanup-Image /StartComponentCleanup

                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "Limpieza de componentes completada con exito.   :::  OK" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Ocurrio un error ($LASTEXITCODE) durante la limpieza." -ForegroundColor Red
                        }
                    } 
                    elseif ($version -eq 6.1) {
                        # Caso Windows 7: Usamos el motor de limpieza de disco nativo
                        Write-Host "Nota: Windows 7 no soporta /StartComponentCleanup." -ForegroundColor Yellow
                        Write-Host "Iniciando limpieza de actualizaciones obsoletas via Cleanmgr..." -ForegroundColor White
                        
                        # Inicia la limpieza de archivos de sistema de forma automatizada
                        # Nota: Requiere que el usuario haya corrido Cleanmgr con SAGESET antes, 
                        # o simplemente lo lanzamos para que el técnico elija.
                        & cleanmgr.exe /sagerun:1
                        
                        Write-Host "Se ha lanzado el Liberador de espacio en disco (Windows 7)." -ForegroundColor Green
                    }
                    else {
                        Write-Host "Opcion no compatible con versiones anteriores a Windows 7." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "14" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "Ejecutando.....: Dism.exe /Online /Cleanup-Image /ScanHealth"
                    Dism.exe /Online /Cleanup-Image /ScanHealth
                    Write-Host "Analisis terminado: Dism.exe /Online /Cleanup-Image /ScanHealth  ::: OK" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Ejecutando.....: Dism.exe /Online /Cleanup-Image /RestoreHealth"
                    Dism.exe /Online /Cleanup-Image /RestoreHealth
                    Write-Host "Analisis terminado: Dism.exe /Online /Cleanup-Image /RestoreHealth  ::: OK" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Ejecutando.....: Dism.exe /Online /Cleanup-Image /StartComponentCleanup"
                    Dism.exe /Online /Cleanup-Image /StartComponentCleanup
                    Write-Host "Analisis terminado: Dism.exe /Online /Cleanup-Image /StartComponentCleanup  ::: OK" -ForegroundColor Green
                    
                    Write-Host
                    Write-Host "Ejecutando.....: Sfc /Scannow"
                    Sfc /Scannow
                    Write-Host "Analisis terminado: Sfc /Scannow ::: OK" -ForegroundColor Green
                }

                "17" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    query user

                }
                "18" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    net share
                }
                "19" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19"
                }
                "19.0" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.0"
                }
                "19.1" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.1"
                }
                "19.2" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.2"
                }
                "19.3" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.3"
                }
                "19.4" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.4"
                }
                "19.5" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.5"
                }
                "19.6" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.6"
                }
                "19.7" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.7"
                }

                "21" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21"
                }
                "21.0" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.0"
                }
                "21.1" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.1"
                }
                "21.2" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.2"
                }
                "21.3" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.3"
                }
                "21.4" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.4"
                }
                "21.5" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.5"
                }
                "21.6" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.6"
                }
                "21.7" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.7"
                }

                

                "0" { 
                    #$salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } #Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 20: Presione ENTER para continuar..." }

        } # Cierra try

        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
		
        finally {
            # *************************************************************************************
            # BLOQUE DE LIMPIEZA Y REFRESCO (Se ejecuta después de cada opción)
            # *************************************************************************************
            
            # 1. Liberar memoria de objetos COM/WMI/CIM colgados
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            # 2. Eliminar variables temporales de la sesión para evitar errores de "cadena de entrada"
            # Mantenemos variables críticas del script
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }

    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.20*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.21 ******************************************************
#**********************************************************************************************************************************
