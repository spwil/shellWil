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
        Write-Host "`n[DISKPART] Procesando directivas de particionado y formateo..." -ForegroundColor Cyan
        $proc = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s `"$tempFile`"" -NoNewWindow -PassThru -Wait
        return $proc.ExitCode
    }
    catch {
        Write-Host "`n[ERROR DISKPART]: $_" -ForegroundColor Red
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
    Write-Header "OPCION 19.3: PREPARACION Y FORMATEO EN MBR PARA S.O. WINDOWS - PARTICION ACTIVA"

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
    $discoSel = Read-Host "`nIngrese el numero de disco a formatear en MBR"
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
    Write-Host "  1. NTFS  (Recomendado para Windows Vista/7/8/10/11 en BIOS Legacy, soporta archivos > 4GB)"
    Write-Host "  2. FAT32 (Universal, para herramientas de rescate/WinPE. Limite max 4GB por archivo)"
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
    $etiqueta = if ($labelInput.Trim()) { $labelInput.Trim().Replace(" ", "_") } else { "WIN_MBR" }

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
        "active",
        "format fs=$fs $paramQuick label=`"$etiqueta`"",
        "assign",
        "exit"
    )

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] El disco $discoIndex ha sido formateado en MBR y su particion esta ACTIVA." -ForegroundColor Green

        # Inyectar código BOOTMGR si bootsect existe
        try {
            $nuevoVol = Get-Partition -DiskNumber $discoIndex -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } | Select-Object -First 1
            if ($nuevoVol -and (Get-Command bootsect.exe -ErrorAction SilentlyContinue)) {
                $driveL = "$($nuevoVol.DriveLetter):"
                Write-Host "Inyectando cargador maestro BOOTMGR con bootsect en $driveL..." -ForegroundColor Cyan
                & bootsect.exe /nt60 $driveL /mbr
                Write-Host "[OK] Codigo BOOTMGR instalado con exito." -ForegroundColor Green
            }
        } catch {}

        Write-Host "`nEl disco esta listo para uso y preparado para arranque en sistemas Legacy BIOS." -ForegroundColor Cyan
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Format-DiskStorageGPT {
    cabecera
    Write-Header "OPCION 19.4: PREPARACION Y FORMATEO EN GPT PARA S.O. WINDOWS - MODO UEFI"

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
    $discoSel = Read-Host "`nIngrese el numero de disco a formatear en GPT"
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
    Write-Host "  1. FAT32 (Estandar UEFI para USB de instalacion. Maximo 4GB por archivo)"
    Write-Host "  2. NTFS  (Para disco principal de sistema C: o instaladores UEFI con soporte NTFS)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $fsOpt = Read-Host "`nElija el sistema de archivos (1 o 2)"
    $fs = switch ($fsOpt) {
        "1" { "fat32" }
        "2" { "ntfs" }
        Default { "" }
    }
    if ($fs -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
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
    $etiqueta = if ($labelInput.Trim()) { $labelInput.Trim().Replace(" ", "_") } else { "WIN_UEFI" }

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

function Format-DiskStorageExFAT {
    cabecera
    Write-Header "OPCION 19.5: PREPARACION Y FORMATEO EN exFAT - PARTICION UNICA LISTA"

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
    $discoSel = Read-Host "`nIngrese el numero de disco a formatear en exFAT"
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

    # 1. Selección de Estilo de Partición
    Write-Host "`n--- SELECCION DE ESTILO DE PARTICION PARA exFAT ---" -ForegroundColor Cyan
    Write-Host "  1. MBR (Recomendado para <= 2TB y compatibilidad con Smart TVs, equipos multimedia y autorradios)"
    Write-Host "  2. GPT (Recomendado para unidades modernas o capacidades > 2TB)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $estiloOpt = Read-Host "`nElija el estilo de particion (1 o 2)"
    $estilo = switch ($estiloOpt) {
        "1" { "mbr" }
        "2" { "gpt" }
        Default { "" }
    }
    if ($estilo -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
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

    $labelInput = Read-Host "`nIngrese una etiqueta de volumen (Presione ENTER para 'DATOS_EXFAT')"
    $etiqueta = if ($labelInput.Trim()) { $labelInput.Trim().Replace(" ", "_") } else { "DATOS_EXFAT" }

    # 3. Confirmación estricta de seguridad
    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                       ADVERTENCIA CRITICA DE ELIMINACION DE DATOS                        " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran TODAS las particiones y datos del siguiente dispositivo:" -ForegroundColor White
    Write-Host "  - Disco Objetivo  : [Disco $discoIndex] $($targetDisk.FriendlyName)" -ForegroundColor Yellow
    Write-Host "  - Capacidad       : $($targetDisk.SizeGB) GB ($($targetDisk.BusType))" -ForegroundColor Yellow
    Write-Host "  - Esquema         : $($estilo.ToUpper()) (Particion Primaria Unica)" -ForegroundColor Yellow
    Write-Host "  - Sistema Archivos: exFAT ($etiqueta)" -ForegroundColor Yellow
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
        "convert $estilo",
        "create partition primary"
    )
    if ($estilo -eq "mbr") {
        $diskpartCmds += "active"
    }
    $diskpartCmds += @(
        "format fs=exfat $paramQuick label=`"$etiqueta`"",
        "assign",
        "exit"
    )

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] El disco $discoIndex ha sido formateado en exFAT con una sola particion ACTIVA/LISTA." -ForegroundColor Green
        Write-Host "La unidad esta preparada para almacenamiento masivo y compatibilidad multiplataforma (Windows/Mac/Linux/Smart TV)." -ForegroundColor Cyan
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function psSubMenuFormatHDD {
    $salirSub19 = $false
    do {
        cabecera
        Write-Header "OPCION 19. TODO SOBRE FORMAT HDD, SSD Y DISPOSITIVOS USB (PREPARACION S.O.)"
        Write-Host "  19.0 Tabla de relacion: Filesystem vs Particion vs Modo Arranque (BIOS/UEFI)" -ForegroundColor Cyan
        Write-Host "  19.1 Informacion tecnica detallada de la unidad (Particion, FS, Salud SMART)" -ForegroundColor Yellow
        Write-Host "  19.2 Verificacion de sectores y revision de superficie (Superficial vs Profunda)" -ForegroundColor Yellow
        Write-Host "  19.3 Formateo e inicializacion en MBR (FAT32/NTFS) para SO Windows - Particion ACTIVA" -ForegroundColor Yellow
        Write-Host "  19.4 Formateo e inicializacion en GPT (FAT32/NTFS) para SO Windows UEFI - Particion Lista" -ForegroundColor Yellow
        Write-Host "  19.5 Formateo e inicializacion en exFAT (Rapido vs Profundo) - Particion Lista" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  0. V O L V E R   A L   S U B M E N U   2 0" -ForegroundColor White
        Write-Header "=============================================================================="

        $op19 = Read-Host "Seleccione la tarea a realizar en Formateo / Preparacion de Unidades"

        switch ($op19) {
            { $_ -in "19.0", "0.0", "table" } { Show-FormatBootMatrix }
            { $_ -in "19.1", "1" }             { Show-DiskTechnicalDetails }
            { $_ -in "19.2", "2" }             { Invoke-DiskSurfaceCheck }
            { $_ -in "19.3", "3" }             { Format-DiskStorageMBR }
            { $_ -in "19.4", "4" }             { Format-DiskStorageGPT }
            { $_ -in "19.5", "5" }             { Format-DiskStorageExFAT }
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
        Despacha la ejecución de las funciones del Grupo 19 (Formateo y Preparación de Discos/USB)
        a un proceso y ventana de consola independiente de PowerShell, liberando inmediatamente la
        consola principal para el operador.
    .PARAMETER OpcionDestino
        Código de la opción a ejecutar ("19", "19.0", "19.1", "19.2", "19.3", "19.4", "19.5").
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OpcionDestino
    )

    $taskMap = @{
        "19"   = @{ Titulo = "Submenu 19: Formateo HDD, SSD y USB (Preparacion S.O.)"; Cmd = "psSubMenuFormatHDD" }
        "19.0" = @{ Titulo = "19.0 Matriz Filesystem vs Particion vs Modo Arranque"; Cmd = "Show-FormatBootMatrix" }
        "19.1" = @{ Titulo = "19.1 Ficha Tecnica Detallada y Salud S.M.A.R.T.";     Cmd = "Show-DiskTechnicalDetails" }
        "19.2" = @{ Titulo = "19.2 Verificacion de Sectores y Revision Superficie";  Cmd = "Invoke-DiskSurfaceCheck" }
        "19.3" = @{ Titulo = "19.3 Formateo e Inicializacion en MBR (Particion ACTIVA)"; Cmd = "Format-DiskStorageMBR" }
        "19.4" = @{ Titulo = "19.4 Formateo e Inicializacion en GPT (UEFI Nativo)";  Cmd = "Format-DiskStorageGPT" }
        "19.5" = @{ Titulo = "19.5 Formateo e Inicializacion en exFAT (Multiplataforma)"; Cmd = "Format-DiskStorageExFAT" }
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
        'Format-DiskStorageExFAT',
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
            Write-Host "19. Todo sobre format HDD y SDD (Preparar Disco o USB) [VENTANA EXTERNA]" -ForegroundColor Cyan
            Write-Host "  19.0 Tabla de relacion: Filesystem vs Particion vs Modo Arranque [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.1 Informacion tecnica detallada de la unidad (Particion, FS, Salud SMART) [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.2 Verificacion de sectores y revision de superficie (Superficial vs Profunda) [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.3 Formateo e inicializacion en MBR (FAT32/NTFS) para SO Windows - Particion ACTIVA [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.4 Formateo e inicializacion en GPT (FAT32/NTFS) para SO Windows UEFI - Particion Lista [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.5 Formateo e inicializacion en exFAT (Rapido vs Profundo) - Particion Lista [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "21. Preparar Dipositivo Externo para instalacion y/o Recuperacion"
            Write-Host "  21.1 USB externo para instalacion de S.O. en MBR-Legacy - Win7 o superior - SIN BootSect" 
            Write-Host "  21.2 USB externo para instalacion de S.O. en MBR-Legacy - Win7 o superior - CON BootSect"
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

                "21.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # Nota: Ejecutar siempre como Administrador.
                    function Preparar-USB-Legacy {
                        Clear-Host
                        Write-Host "--- Herramienta de Preparacion USB Legacy (MBR) ---" -ForegroundColor Cyan
                        Write-Host "Requisito: Ejecutar como Administrador" -ForegroundColor Yellow

                        # 1. Listar unidades extraibles
                        $discos = Get-WmiObject Win32_DiskDrive | Where-Object { $_.InterfaceType -eq "USB" }

                        if ($null -eq $discos) {
                            Write-Host "[ERROR] No se detectaron unidades USB." -ForegroundColor Red
                            return
                        }

                        $discos | Select-Object DeviceID, Model, Size | Format-Table -AutoSize
                        
                        $eleccion = Read-Host "Ingrese el numero de indice del disco (Ejemplo: 1)"
                        
                        if ($null -eq $eleccion -or $eleccion -notmatch '^\d+$') {
                            Write-Host "[ERROR] Entrada invalida. Operacion cancelada." -ForegroundColor Red
                            return
                        }

                        $discoSeleccionado = $discos[$eleccion]
                        $driveLetter = $discoSeleccionado.DeviceID

                        # 2. Confirmacion de seguridad
                        $confirmar = Read-Host "ADVERTENCIA: Se borraran todos los datos en $driveLetter. Continuar? (S/N)"
                        if ($confirmar -ne 'S') {
                            Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
                            return
                        }

                        # 3. Ejecucion de Diskpart mediante Pipe (Estable)
                        try {
                            Write-Host "Procesando particiones mediante Diskpart..." -ForegroundColor Yellow
                            
                            $comandos = (
                                "select disk $eleccion",
                                "clean",
                                "create partition primary",
                                "format fs=ntfs quick",
                                "active",
                                "assign",
                                "exit"
                            )
                            
                            # Envio al pipeline para mantener la consola abierta
                            $comandos | diskpart | Out-Null
                            
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "[EXITO] La unidad ha sido formateada y marcada como Activa." -ForegroundColor Green
                                Write-Host "Para finalizar, ejecuta: bootsect /nt60 X: (donde X es la letra asignada)" -ForegroundColor Cyan
                            }
                            else {
                                Write-Host "[ERROR] Diskpart finalizo con codigo de error: $LASTEXITCODE" -ForegroundColor Red
                            }
                            
                        }
                        catch {
                            Write-Host "[ERROR CRITICO] Ocurrio un fallo durante la operacion: $_" -ForegroundColor Red
                        }
                        finally {
                            Write-Host "`nProceso finalizado." -ForegroundColor Cyan
                        }
                    }

                    Preparar-USB-Legacy
                    
                }

                "21.2" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    
                }

                "21.3" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    
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
