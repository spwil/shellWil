function psSubMenu21 {
    

    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header "21. ---)) LOCAL: VENTANAS ADMINISTRACION WINDOWS - ANTIVIRUS."
            Write-Host "1. Reestablecer la tienda de Windows."
            Write-Host "2. Clave de Sistema Operativo Windows."
            Write-Host "3. Eliminar "Desktop.ini" (Aviso que se ejecuta automaticamente)."
            Write-Host "-----------------------------------------------------------."
            Write-Host "4. Web Definicion ANTIVIRUS DE WINDOWS."
            Write-Host "***********************************************************."
            Write-Host "5. Administracion de Discos Duros."
            Write-Host "6. Administrador de dispositivos."
            Write-Host "7. Administracion de Impresion."
            Write-Host "8. Conexion de Red."
            Write-Host "9. Herramienta de Diagnostico DirectX."
            Write-Host "10. Informacion del Sistema - VENTANA."
            Write-Host "***********************************************************."
            Write-Host ""
            Write-Host "0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "=========================================================="
            
            $op21 = Read-Host "Seleccione la tarea a realizar"

            switch ($op21) {
                "1" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process "wsreset" -Wait

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "2" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    $licencia = (Get-WmiObject SoftwareLicensingService).OA3xOriginalProductKey

                    if ([string]::IsNullOrWhiteSpace($licencia)) {
                        Write-Warning "No se encontró una clave OA3.0 en el firmware de este equipo."
                    }
                    else {
                        Write-Host "La clave detectada es: $licencia" -ForegroundColor Green
                    }

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""

                }
                "3" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    # 1. Definimos las rutas usando variables de entorno para mayor compatibilidad
                    $rutas = @(
                        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\desktop.ini",
                        "$env:Public\Desktop\desktop.ini"
                    )

                    Write-Host "Has elegido ELIMINAR archivos desktop.ini." -ForegroundColor Cyan

                    foreach ($ruta in $rutas) {
                        if (Test-Path -Path $ruta) {
                            try {
                                # -Force es necesario porque desktop.ini tiene atributos de sistema/oculto
                                Remove-Item -Path $ruta -Force -ErrorAction Stop
                                Write-Host "Eliminado con exito: $ruta" -ForegroundColor Green
                            }
                            catch {
                                Write-Warning "No se pudo eliminar $ruta. Es posible que requiera permisos de Administrador."
                            }
                        }
                        else {
                            Write-Host "El archivo no existe en: $ruta" -ForegroundColor Gray
                        }
                    }

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                    
                }
                
                "4" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process "https://www.microsoft.com/en-us/wdsi/definitions"       

                    # Este comando descarga e instala las últimas definiciones silenciosamente
                    Update-MpSignature     

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""  

                }
                "5" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process diskmgmt.msc
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "6" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process devmgmt.msc
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                
                "7" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process printmanagement.msc
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "8" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process ncpa.cpl
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
        
                "9" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process dxdiag  -Wait
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "10" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process msinfo32
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                
                "0" { 
                    #$salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } #Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 21: Presione ENTER para continuar..." }

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

#************************************************* FIN SUB MENU.21*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.22 ******************************************************
#**********************************************************************************************************************************
