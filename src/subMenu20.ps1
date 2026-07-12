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
            Write-Host "19. Todo sobre format HDD y SDD"
            Write-Host "  19.1 Formateo y verificacion  de sectores: format X: /fs:ntfs /p:1" -ForegroundColor Cyan
            Write-Host "  19.2 Formateo formateo rapido NTFS: format.com $letraLimpia /fs:ntfs /q" -ForegroundColor Cyan
            Write-Host "  19.3 Formateo formateo rapido FAT32: format.com $letraLimpia /fs:fat32 /q" -ForegroundColor Cyan
            Write-Host "  19.4 Formateo formateo rapido exFAT: format.com $letraLimpia /fs:exfat /q" -ForegroundColor Cyan
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

                    Write-Host "`n******* ANALISIS DETALLADO DE UNIDADES SSD *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Verificar si existe Get-PhysicalDisk (Windows 8+)
                    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
                        # Obtenemos los discos filtrando por SSD
                        $ssds = Get-PhysicalDisk | Where-Object { $_.MediaType -eq 'SSD' }

                        if ($null -eq $ssds) {
                            Write-Host "No se detectaron unidades SSD en este equipo." -ForegroundColor Yellow
                        }
                        else {
                            foreach ($disk in $ssds) {
                                # Obtenemos detalles adicionales de almacenamiento
                                $storageDetails = $disk | Get-StorageReliabilityCounter

                                Write-Host "[ Unidad: $($disk.FriendlyName) ]" -ForegroundColor White -BackgroundColor DarkBlue
                                
                                # Tabla de información técnica compatible
                                New-Object PSObject -Property @{
                                    "Numero"      = $disk.DeviceID
                                    "Modelo"      = $disk.FriendlyName
                                    "Protocolo"   = $disk.BusType  # NVMe, SATA, USB
                                    "Capacidad"   = "$([Math]::Round($disk.Size / 1GB, 2)) GB"
                                    "EstadoSalud" = $disk.HealthStatus
                                    "Uso_Vida"    = (if ($storageDetails.Wear -ne $null) { "$($storageDetails.Wear)%" } else { "N/A" })
                                    "Temp"        = (if ($storageDetails.Temperature -ne $null) { "$($storageDetails.Temperature)°C" } else { "N/A" })
                                    "N_Serie"     = (if ($disk.SerialNumber) { $disk.SerialNumber.Trim() } else { "Desconocido" })
                                } | Select-Object Numero, Modelo, Protocolo, Capacidad, EstadoSalud, Uso_Vida, Temp, N_Serie | Format-List
                                
                                Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                            }
                        }
                    }
                    else {
                        Write-Host "Nota: Get-PhysicalDisk no esta disponible en este sistema operativo (compatible en Windows 8+)." -ForegroundColor Yellow
                        Write-Host "Obteniendo informacion basica de unidades fisicas a traves de WMI..." -ForegroundColor Yellow
                        Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                        
                        $discosWmi = Get-WmiObject Win32_DiskDrive
                        foreach ($d in $discosWmi) {
                            Write-Host "[ Unidad: $($d.Model) ]" -ForegroundColor White -BackgroundColor DarkBlue
                            New-Object PSObject -Property @{
                                 "Numero"      = $d.Index
                                 "Modelo"      = $d.Model
                                 "Protocolo"   = $d.InterfaceType
                                 "Capacidad"   = "$([Math]::Round([double]$d.Size / 1GB, 2)) GB"
                                 "EstadoSalud" = $d.Status
                                 "Uso_Vida"    = "N/A (Requiere Windows 8+)"
                                 "Temp"        = "N/A (Requiere Windows 8+)"
                                 "N_Serie"     = (if ($d.SerialNumber) { $d.SerialNumber.Trim() } else { "Desconocido" })
                             } | Select-Object Numero, Modelo, Protocolo, Capacidad, EstadoSalud, Uso_Vida, Temp, N_Serie | Format-List
                            
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
                "19.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # ==============================================================================
                    # SCRIPT DE FORMATEO SEGURO DE UNIDADES (Compatible con Windows 7 hasta Windows 11)
                    # ==============================================================================
                    Clear-Host
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "       HERRAMIENTA DE FORMATEO SEGURO GMSANTACRUZ   " -ForegroundColor Cyan
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "NOTA: El parametro /p:1 realiza un formateo lento escribiendo ceros" -ForegroundColor Yellow
                    Write-Host "en cada sector de la unidad para mayor seguridad.`n" -ForegroundColor Yellow

                    # Bucle contenedor de una sola ejecucion para permitir salidas limpias usando 'break'
                    do {
                        # 1. Listar las unidades disponibles usando WMI (Compatibilidad total con Win 7)
                        Write-Host "--- Unidades de Disco Detectadas ---" -ForegroundColor White
                        $unidades = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 }

                        if ($null -eq $unidades) {
                            Write-Host "[ERROR] No se encontraron unidades de almacenamiento validas." -ForegroundColor Red
                            break # Sale de la opcion de formateo de manera segura sin cerrar la consola
                        }

                        # Mostrar las unidades en un formato limpio
                        foreach ($u in $unidades) {
                            # Convertir tamaño a GB de forma compatible con .NET
                            $tamanoGB = if ($u.Size) { [Math]::Round($u.Size / 1GB, 2) } else { "Desconocido" }
                            $libreGB = if ($u.FreeSpace) { [Math]::Round($u.FreeSpace / 1GB, 2) } else { "Desconocido" }
                            
                            # Determinar tipo de unidad de forma amigable
                            $tipo = if ($u.DriveType -eq 2) { "Extraible/USB" } else { "Disco Local" }
                            
                            Write-Host "  -> Unidad: [$($u.DeviceID)] | Tipo: $tipo | Etiqueta: $($u.VolumeName) | Tamano: $tamanoGB GB | Libre: $libreGB GB" -ForegroundColor Green
                        }

                        # 2. Captura y validación de la unidad elegida
                        Write-Host "`n--- Seleccion de Unidad ---" -ForegroundColor White
                        $unidadElegida = (Read-Host "Ingrese la letra de la unidad a formatear (Ej: X o X:)").Trim().ToUpper()

                        # Limpiar la entrada por si el usuario introduce "X:" o solo "X"
                        if ($unidadElegida -match "^[A-Z]:$") {
                            $letraLimpia = $unidadElegida
                        }
                        elseif ($unidadElegida -match "^[A-Z]$") {
                            $letraLimpia = "$unidadElegida" + ":"
                        }
                        else {
                            Write-Host "[ERROR] Formato de letra de unidad no valido." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Verificar que la unidad seleccionada exista en la lista detectada
                        $verificarUnidad = $unidades | Where-Object { $_.DeviceID -eq $letraLimpia }

                        if ($null -eq $verificarUnidad) {
                            Write-Host "[ERROR] La unidad $letraLimpia no existe o no esta disponible para formatear." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Evitar formatear por accidente la unidad del sistema (C:)
                        if ($letraLimpia -eq "C:") {
                            Write-Host "[ADVERTENCIA CRITICA] No esta permitido formatear la unidad del sistema (C:) por seguridad." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 3. Doble confirmación de seguridad antes de proceder
                        Write-Host "`n==================================================" -ForegroundColor Red
                        Write-Host "¡ADVERTENCIA CRITICA! SE PERDERAN TODOS LOS DATOS EN LA UNIDAD $letraLimpia" -ForegroundColor Red
                        Write-Host "==================================================" -ForegroundColor Red
                        $confirmacion1 = Read-Host "Esta seguro de que desea continuar, Escriba 'Y' para confirmar"

                        if ($confirmacion1 -ne "Y") {
                            Write-Host "Proceso cancelado por el usuario." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        $confirmacion2 = Read-Host "Ultima confirmacion: Ingrese nuevamente la letra de la unidad para proceder ($letraLimpia)"
                        if ($confirmacion2.Trim().ToUpper() -ne $letraLimpia.Replace(":", "")) {
                            Write-Host "`nLas confirmaciones no coinciden. Proceso abortado de manera segura." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 4. Ejecución del comando de Formateo
                        Write-Host "`nIniciando formateo NTFS seguro de la unidad $letraLimpia con verificacion de sectores (/p:1)..." -ForegroundColor Cyan
                        Write-Host "Por favor, siga las instrucciones en pantalla del comando nativo de Windows:`n" -ForegroundColor Yellow

                        try {
                            # Invocación directa del ejecutable del sistema
                            & format.com $letraLimpia /fs:ntfs /p:1
                            Write-Host "`n[EXITO] El proceso de formateo ha concluido en la unidad $letraLimpia." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "`n[ERROR OCURRIDO]: $_" -ForegroundColor Red
                        }

                    } while ($false) # El ciclo siempre evalua a falso para ejecutarse exactamente una vez

                    # Cierre ordenado y controlado (La consola nunca se cierra sola)
                    Write-Host "`n==================================================" -ForegroundColor Cyan
                    

                }

                "19.2" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # ==============================================================================
                    # SCRIPT DE FORMATEO RÁPIDO DE UNIDADES (Compatible con Windows 7 hasta Windows 11)
                    # ==============================================================================
                    Clear-Host
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "       HERRAMIENTA DE FORMATEO RÁPIDO GMSANTACRUZ   " -ForegroundColor Cyan
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "NOTA: El parametro /q realiza un formateo rapido liberando el indice" -ForegroundColor Yellow
                    Write-Host "de archivos en pocos segundos de manera eficiente.`n" -ForegroundColor Yellow

                    # Bucle contenedor de una sola ejecucion para permitir salidas limpias usando 'break'
                    do {
                        # 1. Listar las unidades disponibles usando WMI (Compatibilidad total con Win 7)
                        Write-Host "--- Unidades de Disco Detectadas ---" -ForegroundColor White
                        $unidades = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 }

                        if ($null -eq $unidades) {
                            Write-Host "[ERROR] No se encontraron unidades de almacenamiento validas." -ForegroundColor Red
                            break # Sale de la opcion de formateo de manera segura sin cerrar la consola
                        }

                        # Mostrar las unidades en un formato limpio y ordenado
                        foreach ($u in $unidades) {
                            # Convertir tamaño a GB de forma compatible con .NET
                            $tamanoGB = if ($u.Size) { [Math]::Round($u.Size / 1GB, 2) } else { "Desconocido" }
                            $libreGB = if ($u.FreeSpace) { [Math]::Round($u.FreeSpace / 1GB, 2) } else { "Desconocido" }
                            
                            # Determinar tipo de unidad de forma amigable
                            $tipo = if ($u.DriveType -eq 2) { "Extraible/USB" } else { "Disco Local" }
                            
                            Write-Host "  -> Unidad: [$($u.DeviceID)] | Tipo: $tipo | Etiqueta: $($u.VolumeName) | Tamano: $tamanoGB GB | Libre: $libreGB GB" -ForegroundColor Green
                        }

                        # 2. Captura y validación de la unidad elegida
                        Write-Host "`n--- Seleccion de Unidad ---" -ForegroundColor White
                        $unidadElegida = (Read-Host "Ingrese la letra de la unidad a formatear de forma RAPIDA (Ej: X o X:)").Trim().ToUpper()

                        # Limpiar la entrada por si el usuario introduce "X:" o solo "X"
                        if ($unidadElegida -match "^[A-Z]:$") {
                            $letraLimpia = $unidadElegida
                        }
                        elseif ($unidadElegida -match "^[A-Z]$") {
                            $letraLimpia = "$unidadElegida" + ":"
                        }
                        else {
                            Write-Host "[ERROR] Formato de letra de unidad no valido." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Verificar que la unidad seleccionada exista en la lista detectada
                        $verificarUnidad = $unidades | Where-Object { $_.DeviceID -eq $letraLimpia }

                        if ($null -eq $verificarUnidad) {
                            Write-Host "[ERROR] La unidad $letraLimpia no existe o no esta disponible para formatear." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Evitar formatear por accidente la unidad del sistema (C:)
                        if ($letraLimpia -eq "C:") {
                            Write-Host "[ADVERTENCIA CRITICA] No esta permitido formatear la unidad del sistema (C:) por seguridad." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 3. Doble confirmación de seguridad antes de proceder
                        Write-Host "`n==================================================" -ForegroundColor Red
                        Write-Host "¡ADVERTENCIA CRITICA! SE PERDERAN TODOS LOS DATOS EN LA UNIDAD $letraLimpia" -ForegroundColor Red
                        Write-Host "==================================================" -ForegroundColor Red
                        $confirmacion1 = Read-Host "Esta seguro de que desea continuar con el formateo RAPIDO, Escriba 'Y' para confirmar"

                        if ($confirmacion1 -ne "Y") {
                            Write-Host "Proceso cancelado por el usuario." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        $confirmacion2 = Read-Host "Ultima confirmacion: Ingrese nuevamente la letra de la unidad para proceder ($letraLimpia)"
                        if ($confirmacion2.Trim().ToUpper() -ne $letraLimpia.Replace(":", "")) {
                            Write-Host "`nLas confirmaciones no coinciden. Proceso abortado de manera segura." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 4. Ejecución del comando de Formateo Rápido
                        Write-Host "`nIniciando formateo NTFS RAPIDO de la unidad $letraLimpia (/q)..." -ForegroundColor Cyan
                        Write-Host "Por favor, siga las instrucciones en pantalla del comando nativo de Windows:`n" -ForegroundColor Yellow

                        try {
                            # Se invoca format.com aplicando el parametro /q en lugar de /p:1
                            & format.com $letraLimpia /fs:ntfs /q
                            Write-Host "`n[EXITO] El proceso de formateo rapido ha concluido en la unidad $letraLimpia." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "`n[ERROR OCURRIDO]: $_" -ForegroundColor Red
                        }

                    } while ($false)

                    # Cierre ordenado y controlado (La consola permanece abierta de forma segura)
                    Write-Host "`n==================================================" -ForegroundColor Cyan

                }

                "19.3" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # ==============================================================================
                    # SCRIPT DE FORMATEO RÁPIDO DE UNIDADES EN FAT32 (Compatible con Windows 7 hasta Windows 11)
                    # ==============================================================================
                    Clear-Host
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "       HERRAMIENTA DE FORMATEO RÁPIDO GMSANTACRUZ   " -ForegroundColor Cyan
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "NOTA: El parametro /q realiza un formateo rapido liberando el indice" -ForegroundColor Yellow
                    Write-Host "de archivos en pocos segundos de manera eficiente.`n" -ForegroundColor Yellow

                    # Bucle contenedor de una sola ejecucion para permitir salidas limpias usando 'break'
                    do {
                        # 1. Listar las unidades disponibles usando WMI (Compatibilidad total con Win 7)
                        Write-Host "--- Unidades de Disco Detectadas ---" -ForegroundColor White
                        $unidades = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 }

                        if ($null -eq $unidades) {
                            Write-Host "[ERROR] No se encontraron unidades de almacenamiento validas." -ForegroundColor Red
                            break # Sale de la opcion de formateo de manera segura sin cerrar la consola
                        }

                        # Mostrar las unidades en un formato limpio y ordenado
                        foreach ($u in $unidades) {
                            # Convertir tamaño a GB de forma compatible con .NET
                            $tamanoGB = if ($u.Size) { [Math]::Round($u.Size / 1GB, 2) } else { "Desconocido" }
                            $libreGB = if ($u.FreeSpace) { [Math]::Round($u.FreeSpace / 1GB, 2) } else { "Desconocido" }
                            
                            # Determinar tipo de unidad de forma amigable
                            $tipo = if ($u.DriveType -eq 2) { "Extraible/USB" } else { "Disco Local" }
                            
                            Write-Host "  -> Unidad: [$($u.DeviceID)] | Tipo: $tipo | Etiqueta: $($u.VolumeName) | Tamano: $tamanoGB GB | Libre: $libreGB GB" -ForegroundColor Green
                        }

                        # 2. Captura y validación de la unidad elegida
                        Write-Host "`n--- Seleccion de Unidad ---" -ForegroundColor White
                        $unidadElegida = (Read-Host "Ingrese la letra de la unidad a formatear de forma RAPIDA (Ej: X o X:)").Trim().ToUpper()

                        # Limpiar la entrada por si el usuario introduce "X:" o solo "X"
                        if ($unidadElegida -match "^[A-Z]:$") {
                            $letraLimpia = $unidadElegida
                        }
                        elseif ($unidadElegida -match "^[A-Z]$") {
                            $letraLimpia = "$unidadElegida" + ":"
                        }
                        else {
                            Write-Host "[ERROR] Formato de letra de unidad no valido." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Verificar que la unidad seleccionada exista en la lista detectada
                        $verificarUnidad = $unidades | Where-Object { $_.DeviceID -eq $letraLimpia }

                        if ($null -eq $verificarUnidad) {
                            Write-Host "[ERROR] La unidad $letraLimpia no existe o no esta disponible para formatear." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Evitar formatear por accidente la unidad del sistema (C:)
                        if ($letraLimpia -eq "C:") {
                            Write-Host "[ADVERTENCIA CRITICA] No esta permitido formatear la unidad del sistema (C:) por seguridad." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 3. Doble confirmación de seguridad antes de proceder
                        Write-Host "`n==================================================" -ForegroundColor Red
                        Write-Host "¡ADVERTENCIA CRITICA! SE PERDERAN TODOS LOS DATOS EN LA UNIDAD $letraLimpia" -ForegroundColor Red
                        Write-Host "==================================================" -ForegroundColor Red
                        $confirmacion1 = Read-Host "Esta seguro de que desea continuar con el formateo RAPIDO, Escriba 'Y' para confirmar"

                        if ($confirmacion1 -ne "Y") {
                            Write-Host "Proceso cancelado por el usuario." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        $confirmacion2 = Read-Host "Ultima confirmacion: Ingrese nuevamente la letra de la unidad para proceder ($letraLimpia)"
                        if ($confirmacion2.Trim().ToUpper() -ne $letraLimpia.Replace(":", "")) {
                            Write-Host "`nLas confirmaciones no coinciden. Proceso abortado de manera segura." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 4. Ejecución del comando de Formateo Rápido en FAT32
                        Write-Host "`nIniciando formateo FAT32 RAPIDO de la unidad $letraLimpia (/q)..." -ForegroundColor Cyan
                        Write-Host "Por favor, siga las instrucciones en pantalla del comando nativo de Windows:`n" -ForegroundColor Yellow

                        try {
                            # Se invoca format.com aplicando el parametro /fs:fat32 y /q
                            & format.com $letraLimpia /fs:fat32 /q
                            Write-Host "`n[EXITO] El proceso de formateo rapido en FAT32 ha concluido en la unidad $letraLimpia." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "`n[ERROR OCURRIDO]: $_" -ForegroundColor Red
                        }

                    } while ($false)

                    # Cierre ordenado y controlado (La consola permanece abierta de forma segura)
                    Write-Host "`n==================================================" -ForegroundColor Cyan
                    Write-Host "Presione ENTER para finalizar el script..."
                    
                }

                "19.4" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # ==============================================================================
                    # SCRIPT DE FORMATEO RÁPIDO DE UNIDADES EN exFAT (Compatible con Windows 7 hasta Windows 11)
                    # ==============================================================================
                    Clear-Host
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "       HERRAMIENTA DE FORMATEO RÁPIDO GMSANTACRUZ   " -ForegroundColor Cyan
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "NOTA: El parametro /q realiza un formateo rapido liberando el indice" -ForegroundColor Yellow
                    Write-Host "de archivos en pocos segundos de manera eficiente.`n" -ForegroundColor Yellow

                    # Bucle contenedor de una sola ejecucion para permitir salidas limpias usando 'break'
                    do {
                        # 1. Listar las unidades disponibles usando WMI (Compatibilidad total con Win 7)
                        Write-Host "--- Unidades de Disco Detectadas ---" -ForegroundColor White
                        $unidades = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 }

                        if ($null -eq $unidades) {
                            Write-Host "[ERROR] No se encontraron unidades de almacenamiento validas." -ForegroundColor Red
                            break # Sale de la opcion de formateo de manera segura sin cerrar la consola
                        }

                        # Mostrar las unidades en un formato limpio y ordenado
                        foreach ($u in $unidades) {
                            # Convertir tamaño a GB de forma compatible con .NET
                            $tamanoGB = if ($u.Size) { [Math]::Round($u.Size / 1GB, 2) } else { "Desconocido" }
                            $libreGB = if ($u.FreeSpace) { [Math]::Round($u.FreeSpace / 1GB, 2) } else { "Desconocido" }
                            
                            # Determinar tipo de unidad de forma amigable
                            $tipo = if ($u.DriveType -eq 2) { "Extraible/USB" } else { "Disco Local" }
                            
                            Write-Host "  -> Unidad: [$($u.DeviceID)] | Tipo: $tipo | Etiqueta: $($u.VolumeName) | Tamano: $tamanoGB GB | Libre: $libreGB GB" -ForegroundColor Green
                        }

                        # 2. Captura y validación de la unidad elegida
                        Write-Host "`n--- Seleccion de Unidad ---" -ForegroundColor White
                        $unidadElegida = (Read-Host "Ingrese la letra de la unidad a formatear de forma RAPIDA (Ej: X o X:)").Trim().ToUpper()

                        # Limpiar la entrada por si el usuario introduce "X:" o solo "X"
                        if ($unidadElegida -match "^[A-Z]:$") {
                            $letraLimpia = $unidadElegida
                        }
                        elseif ($unidadElegida -match "^[A-Z]$") {
                            $letraLimpia = "$unidadElegida" + ":"
                        }
                        else {
                            Write-Host "[ERROR] Formato de letra de unidad no valido." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Verificar que la unidad seleccionada exista en la lista detectada
                        $verificarUnidad = $unidades | Where-Object { $_.DeviceID -eq $letraLimpia }

                        if ($null -eq $verificarUnidad) {
                            Write-Host "[ERROR] La unidad $letraLimpia no existe o no esta disponible para formatear." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Evitar formatear por accidente la unidad del sistema (C:)
                        if ($letraLimpia -eq "C:") {
                            Write-Host "[ADVERTENCIA CRITICA] No esta permitido formatear la unidad del sistema (C:) por seguridad." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 3. Doble confirmación de seguridad antes de proceder
                        Write-Host "`n==================================================" -ForegroundColor Red
                        Write-Host "¡ADVERTENCIA CRITICA! SE PERDERAN TODOS LOS DATOS EN LA UNIDAD $letraLimpia" -ForegroundColor Red
                        Write-Host "==================================================" -ForegroundColor Red
                        $confirmacion1 = Read-Host "Esta seguro de que desea continuar con el formateo RAPIDO, Escriba 'Y' para confirmar"

                        if ($confirmacion1 -ne "Y") {
                            Write-Host "Proceso cancelado por el usuario." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        $confirmacion2 = Read-Host "Ultima confirmacion: Ingrese nuevamente la letra de la unidad para proceder ($letraLimpia)"
                        if ($confirmacion2.Trim().ToUpper() -ne $letraLimpia.Replace(":", "")) {
                            Write-Host "`nLas confirmaciones no coinciden. Proceso abortado de manera segura." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 4. Ejecución del comando de Formateo Rápido en exFAT
                        Write-Host "`nIniciando formateo exFAT RAPIDO de la unidad $letraLimpia (/q)..." -ForegroundColor Cyan
                        Write-Host "Por favor, siga las instrucciones en pantalla del comando nativo de Windows:`n" -ForegroundColor Yellow

                        try {
                            # Se invoca format.com aplicando el parametro /fs:exfat y /q
                            & format.com $letraLimpia /fs:exfat /q
                            Write-Host "`n[EXITO] El proceso de formateo rapido en exFAT ha concluido en la unidad $letraLimpia." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "`n[ERROR OCURRIDO]: $_" -ForegroundColor Red
                        }

                    } while ($false)

                    # Cierre ordenado y controlado (La consola permanece abierta de forma segura)
                    Write-Host "`n==================================================" -ForegroundColor Cyan
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
