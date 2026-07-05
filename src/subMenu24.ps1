function psSubMenu24 {
    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 24. *****)) COMANDOS WINDOWS 11 *****"
            Write-Host "  1. Abrir Dispositivos e Impresoras."
            Write-Host "  2. Configuracion de Dispositivos General."
            Write-Host "  3. Accesibilidad - Filtros de Color."
            Write-Host "  4. Accesibilidad - Puntero Mouse."
            Write-Host "  5. Accesibilidad - Cursor Texto."
            Write-Host "  6. PANTALLA PRINCIPAL - CONFIGURACION."
            Write-Host "  7. Pantalla de Dispositivos e Impresoras."
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "===================================================================="
            
            $op24 = Read-Host "Seleccione la tarea a realizar"

            switch ($op24) {
                "1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"

                    Write-Host "--- ABRIENDO PANEL DE DISPOSITIVOS E IMPRESORAS ---" -ForegroundColor Cyan

                    try {
                        # El comando 'shell:::' funciona en el explorador de archivos de todas las versiones de Windows
                        Start-Process "shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}"
                        Write-Host "Ventana abierta correctamente." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error: No se pudo abrir la ventana de impresoras." -ForegroundColor Red
                    }

                }
                "2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"

                    # Obtener la version mayor del sistema (6 = Win 7/8, 10 = Win 10/11)
                    $osVersion = [Environment]::OSVersion.Version.Major

                    if ($osVersion -ge 10) {
                        Write-Host "Detectado Windows 10/11. Abriendo Configuracion Moderna..." -ForegroundColor Cyan
                        Start-Process "ms-settings:printers"
                    } else {
                        Write-Host "Detectado Windows antiguo. Abriendo Panel de Control clasico..." -ForegroundColor Yellow
                        Start-Process "control" -ArgumentList "printers"
                    }

                    Write-Host " "

                }

                "3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"

                    
                    # 1. Identificar la versión del sistema
                    $osVersion = [Environment]::OSVersion.Version.Major

                    Write-Host "--- AABRIENDO CONFIGURACION DE COLOR Y ACCESIBILIDAD ---" -ForegroundColor Cyan
                    
                    # $os = Get-WmiObject Win32_OperatingSystem

                    if ($osVersion -ge 10) {
                        # Windows 10 y 11: Abrir filtros de color directamente
                        Write-Host "Detectado Windows 10/11. Abriendo Filtros de Color..." -ForegroundColor Green
                        Start-Process "ms-settings:easeofaccess-colorfilter"
                    } 
                    else {
                        # Windows 7 y 8: Abrir el Centro de Accesibilidad clásico
                        Write-Host "Windows 7/8 detectado. Abriendo Centro de Accesibilidad (Optimizar presentacion visual)..." -ForegroundColor Yellow
                        # El ID 0x17 corresponde a la optimización de pantalla
                        Start-Process "control.exe" -ArgumentList "/name Microsoft.EaseOfAccessCenter", "/page pageVisualOptimization"
                        
                        # Para win 10
                        Write-Host "Windows 10 o posterior..." -ForegroundColor Yellow
                        Start-Process "ms-settings:easeofaccess-colorfilter"
                    }

                    Write-Host " "
            
                }

                "4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"


                    # 1. Identificar la versión del sistema
                    $osVersion = [Environment]::OSVersion.Version.Major
                    Write-Host "--- ABRIENDO CONFIGURACION DE PUNTERO Y MOUSE ---" -ForegroundColor Cyan


                    if ($osVersion -ge 10) {
                        # Windows 10 y 11: Abrir la interfaz moderna de Accesibilidad
                        Write-Host "Detectado Windows 10/11. Abriendo configuracion moderna..." -ForegroundColor Green
                        Start-Process "ms-settings:easeofaccess-mousepointer"
                    } 
                    else {
                        # Windows 7 y 8: Abrir las Propiedades del Mouse clásicas
                        Write-Host "Detectado Windows 7/8. Abriendo Panel de Control clasico..." -ForegroundColor Yellow
                        # 'main.cpl' es el archivo de sistema para las propiedades del mouse
                        Start-Process "control.exe" -ArgumentList "main.cpl,,1" 

                        # Para win 10
                        Write-Host "Windows 10 o posterior..." -ForegroundColor Yellow
                        Start-Process "ms-settings:easeofaccess-mousepointer"
                    }
                    Write-Host " "

                }            

                "5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"


                    # 1. Identificar la versión del sistema
                    $osVersion = [Environment]::OSVersion.Version.Major
                    Write-Host "--- ABRIENDO CONFIGURACION DE CURSOR DE TEXTO ---" -ForegroundColor Cyan

                    if ($osVersion -ge 10) {
                        # Windows 10 y 11: Abrir la interfaz moderna de accesibilidad del cursor
                        Write-Host "Detectado Windows 10/11. Abriendo configuracion moderna..." -ForegroundColor Green
                        Start-Process "ms-settings:easeofaccess-cursor"
                    } 
                    else {
                        # Windows 7 y 8: Abrir el Centro de Accesibilidad en la sección de optimización visual
                        Write-Host "Detectado Windows 7/8. Abriendo Centro de Accesibilidad clasico..." -ForegroundColor Yellow
                        # Esta página permite ajustar el grosor del cursor de parpadeo en versiones antiguas
                        Start-Process "control.exe" -ArgumentList "/name Microsoft.EaseOfAccessCenter", "/page pageVisualOptimization"

                        # Para win 10
                        Write-Host "Windows 10 o posterior..." -ForegroundColor Yellow
                        Start-Process "ms-settings:easeofaccess-cursor"


                    }
                    Write-Host " "

                }
                "6" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"

                    # 1. Identificar la versión del sistema
                    $osVersion = [Environment]::OSVersion.Version.Major

                    Write-Host "--- ABRIENDO CONFIGURACION ADICIONAL (EXTRAS) ---" -ForegroundColor Cyan

                    if ($osVersion -ge 10) {
                        # Windows 10 y 11: Intentar abrir la sección de Extras moderna
                        Write-Host "Detectado Windows 10/11. Abriendo Extras/Configuracion adicional..." -ForegroundColor Green
                        # Nota: Si el fabricante no incluyó extras, esta página podría abrir el Inicio de Configuración
                        Start-Process "ms-settings:extras"
                    } 
                    else {
                        # Windows 7 y 8: Abrir el Panel de Control principal
                        # Dado que 'extras' no existe como tal, abrimos la vista de iconos para que el usuario elija
                        Write-Host "Detectado Windows 7/8. Abriendo Panel de Control (Vista de iconos)..." -ForegroundColor Yellow
                        Start-Process "control.exe"
                    }
                    Write-Host " "

                }

                "7" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"
                    
                    Write-Host "--- ACCEDIENDO A DISPOSITIVOS E IMPRESORAS ---" -ForegroundColor Cyan

                    try {
                        # El protocolo 'shell:::' es el método más estable entre versiones de SO
                        Start-Process "shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}"
                        Write-Host "Ventana abierta con exito." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error: No se pudo invocar la interfaz de dispositivos." -ForegroundColor Red
                    }
                    Write-Host " "

                }
                
                "0" { 
                    # $salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            }  # Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 24: Presione ENTER para continuar..." }
        } #Cierra try

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

#************************************************* FIN SUB MENU.24*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.25 ******************************************************
#**********************************************************************************************************************************
