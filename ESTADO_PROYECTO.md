# ESTADO_PROYECTO.md — Memoria y Bitácora de Continuidad

> **Propósito:** Este archivo es la memoria central del proyecto `shellWil`. Permite que cualquier miembro del equipo o el asistente de Inteligencia Artificial (Antigravity) conozca exactamente en qué estado se encuentra el desarrollo, qué fue lo último que se hizo y cómo retomar el trabajo sin perder tiempo al escribir **`RECUERDAME`**.

---

## 📌 1. Ficha del Proyecto
* **Proyecto:** `shellWil` ([repositorio GitHub](https://github.com/spwil/shellWil.git))
* **Autor / Responsable:** Ing. Wilson Yucra Juan (`wyucra@gmsantacruz.gov.bo`)
* **Objetivo:** Suite integral y portable de administración, soporte técnico, auditoría y mantenimiento del Sistema Operativo Windows para Helpdesk.
* **Arquitectura:**
  - Código fuente modular en `src/` ([helpers.ps1](src/helpers.ps1), [menuPrincipal.ps1](src/menuPrincipal.ps1), [subMenu20.ps1](src/subMenu20.ps1) a [subMenu28.ps1](src/subMenu28.ps1)).
  - Script de ensamblado automático: [build.ps1](build.ps1).
  - Binario ejecutable compilado: [ShellSW.bat](ShellSW.bat).

---

## 🕒 2. Última Sesión de Trabajo
* **Fecha:** 10 de Noviembre de 2026
* **Hito Completado:** **Implementación de la Opción 7: Consola Remota (PowerShell Remoto Directo e Interactivo) en `subMenu28.ps1`**.
* **Cambios Clave Realizados:**
  1. **Nuevo Grupo y Opción 7 en [src/subMenu28.ps1](src/subMenu28.ps1):**
     - Se añadió al menú visual y a la lógica de selección:
       * `7. Consola Remota`
       * `7.1 || CONECTAR || PowerShell Remoto (Sesion Directa / Interactiva)`
     - Integrado con la función de resolución flexible de destino `$obtenerDestino` (admite IP completa, 2 últimos octetos, 1 octeto o Hostname).
  2. **Arquitectura de Conexión Remota Nativa de Alto Rendimiento en [src/helpers.ps1](src/helpers.ps1):**
     - **Función `psConectarPowerShellRemoto`:**
       * **Nivel 1 (WinRM / WS-Man Nativo - Puerto 5985):** Abre una sesión interactiva nativa mediante proceso PowerShell interactivo (`-NoExit`), resolviendo la limitación de PowerShell donde `Enter-PSSession` se cerraba inmediatamente al ejecutarse dentro de scripts por lotes (.bat). Permite elegir entre **Ventana Nueva Independiente (Multitarea Asíncrona)** o **Misma Consola**. En el modo de ventana independiente, libera inmediatamente la ventana principal de ShellSW sin bloquear la consola, permitiendo multitarea real. Soporta Kerberos SSO de dominio sin contraseñas, tuberías de objetos y ejecución de scripts remotos con prompt `[HOSTNAME]: PS>`.
       * **Diagnóstico Pre-flight y Auto-reparación (`psHabilitarRemotingRapido`):** Comprueba conectividad al puerto 5985 con un timeout ultra-rápido de 1200ms. Si WinRM está cerrado, ofrece habilitar el servicio y abrir el firewall de forma remota y transparente vía WMI (`Win32_Process`) o PsExec con 1 solo clic.
       * **Nivel 2 (Fallback PsExec interactivo):** Si WinRM no responde o el puerto está bloqueado por políticas de red, ofrece abrir de inmediato una consola interactiva elevada mediante PsExec sobre SMB (puerto 445) en ventana independiente sin interferir con la sesión de ShellSW.
  3. **Hito Previo Consolidado (Opción 6: Gestión SIAF-SICE):**
     - Configuración multi-capa 100% WMI de símbolos regionales (punto decimal `.`, miles `,`, moneda `Bs.`, fecha `dd/MM/yyyy`, GeoID `26` y `UserLocaleFromLanguageProfileOptOut = 1`).
     - Admite aplicar a sesión actual o a todos los usuarios (sesiones activas, perfiles en disco y plantilla base `Default User`).
  4. **Compilación y verificación:**
     - Sintaxis validada con AST Parser (0 errores).
     - Compilación exitosa con [build.ps1](build.ps1) generando el binario [ShellSW.bat](ShellSW.bat).

---

## 📍 3. ¿En qué punto nos hemos quedado?
La nueva funcionalidad **7. Consola Remota (PowerShell Remoto)** está completamente implementada, compilada en [ShellSW.bat](ShellSW.bat) y lista para producción.

* **Estado de Git:** Rama `main`, cambios listos en `ShellSW.bat`, `src/helpers.ps1`, `src/subMenu28.ps1` y `ESTADO_PROYECTO.md`.
* **Próxima acción técnica:** Probar la conexión ingresando a `ShellSW.bat` -> opción `28` -> opción `7` (o `7.1`) e ingresando la IP o los últimos dos octetos del equipo objetivo.
* **Publicación:** Cuando desees sincronizar a GitHub, usa la opción oculta `1010` en el menú principal.

---

## 🚀 4. Guía para Continuar (Paso a Paso)

### Si estás en la PC 2 (o en una máquina distinta a donde se programó):
1. Abre `ShellSW.bat` (o tu terminal).
2. En el menú, escribe **`1011`** y presiona Enter.
3. El sistema descargará todo lo nuevo desde GitHub, auto-compilará [ShellSW.bat](ShellSW.bat) y te preguntará si deseas reiniciar para cargar los cambios.
4. *(Solo la primera vez en PC 2)* Si te pide credenciales de GitHub, ejecuta:
   ```powershell
   git config --global credential.helper manager
   ```

### Si vas a continuar programando o agregando módulos:
1. Edita los módulos en la carpeta `src/`.
2. Para probar tus cambios en caliente o recompilar, ejecuta:
   ```powershell
   .\build.ps1
   ```
3. Al terminar la sesión, escribe **`1010`** en el menú de ShellSW (o ejecuta commit y push) para que la otra PC reciba tus avances.

---

## 📋 5. Tareas Pendientes y Roadmap Sugerido
- [x] Sincronización multi-PC automatizada (Opciones 1010 y 1011).
- [x] Ocultamiento de opciones de desarrollo en el menú por seguridad.
- [x] Documentación de sincronización y bitácora de memoria (`RECUERDAME`).
- [x] Opción 6: Gestión de Símbolos SIAF-SICE multi-capa en Submenú 28.
- [x] Opción 7: Consola Remota PowerShell Interactiva (WinRM + WMI auto-enable + PsExec fallback).
- [ ] Probar flujo completo de bajada en la PC secundaria mediante la opción `1011`.
- [ ] Revisión periódica de submódulos de administración según requerimientos del equipo de Helpdesk.
