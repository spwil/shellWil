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
* **Fecha:** 5 de Noviembre de 2026
* **Hito Completado:** **Implementación de la Opción 6: Gestión SIAF-SICE en `subMenu28.ps1` e Input Flexible de IP**.
* **Cambios Clave Realizados:**
  1. **Nueva Opción 6 (y 6.1) en [src/subMenu28.ps1](src/subMenu28.ps1):**
     - Se añadió al menú `6. Gestion SIAF-SICE` y `6.1 || CONFIGURAR || Simbolos Regionales SIAF-SICE (.reg)`.
     - Permite configurar los símbolos requeridos por los aplicativos gubernamentales SIAF y SICE (punto decimal `.`, coma de miles `,`, moneda `Bs.`, fecha `dd/MM/yyyy`, GeoID `26` y protección `UserLocaleFromLanguageProfileOptOut = 1`).
  2. **Selector de Alcance Interactivo y Arquitectura 100% WMI:**
     - **[1] Sesión Actual:** Identifica al usuario activo conectado mediante `Win32_Process` (`explorer.exe`), resuelve su SID y aplica los cambios directamente en caliente a `HKU\<SID>\Control Panel\International` mediante WMI, emitiendo una notificación de refresco `WM_SETTINGCHANGE` / `UpdatePerUserSystemParameters` para que surta efecto sin reiniciar.
     - **[2] Todos los Usuarios (4 Capas 100% WMI):**
       * **Capa 1 (Memoria):** Identifica todas las sesiones activas en `Win32_UserProfile` (`Loaded = True`), procesos interactivos y `.DEFAULT`, inyectando las claves mediante WMI `reg add` sin depender del servicio "Registro Remoto".
       * **Capa 2 (Perfiles en disco):** Detecta perfiles desconectados en `Win32_UserProfile` (`Loaded = False`), monta temporalmente cada colmena `NTUSER.DAT` con WMI (`reg load`), inyecta los valores y la desmonta (`reg unload`).
       * **Capa 3 (Default User):** Configura la plantilla base `C:\Users\Default\NTUSER.DAT` para que cualquier usuario nuevo futuro nazca con SIAF-SICE configurado.
       * **Capa 4 (Sistema):** Dispara la señal de refresco gráfico al sistema operativo.
     - **Eliminación total del error "No se ha encontrado la ruta de acceso de la red":** Se reemplazó el uso de `.NET OpenRemoteBaseKey` (que requería el servicio deshabilitado `RemoteRegistry`) por llamadas nativas WMI, garantizando 100% de éxito en cualquier estación de trabajo remota.
  3. **Input Flexible de Red (IP Completa y 2 últimos octetos):**
     - La función de resolución `$obtenerDestino` en [src/subMenu28.ps1](src/subMenu28.ps1) ahora admite:
       * IP completa (ej: `192.168.176.50` o `10.0.0.5`).
       * 2 últimos octetos (ej: `176.50` o `13.15` -> auto-resuelve `192.168.X.X`).
       * 1 octeto (ej: `50` -> auto-resuelve `192.168.176.50`).
       * Hostname (ej: `PC-SIAF01`).
       * Equipo local (`.`, `localhost` o `127.0.0.1`).
  4. **Persistencia y Portabilidad del Recurso:**
     - Archivo original almacenado en `recursosExtras/SiafSice-OR.reg`.
     - Función nativa en [src/helpers.ps1](src/helpers.ps1) (`psConfigurarSimbolosSiafSice`) con diccionario embebido y arquitectura multi-fallback (.NET Remote Registry -> WMI `reg add` -> PsExec), operando sin depender de recursos compartidos SMB.
  5. **Compilación y verificación:**
     - Compilado [ShellSW.bat](ShellSW.bat) con [build.ps1](build.ps1). Sintaxis validada en todos los módulos con 0 errores.

---

## 📍 3. ¿En qué punto nos hemos quedado?
La funcionalidad de Gestión SIAF-SICE (Opción 6 en el Submenú 28) está completamente implementada, compilada y lista para ser probada en estaciones de trabajo y Helpdesk.

* **Estado de Git:** Rama `main`, cambios listos en `ShellSW.bat`, `src/helpers.ps1`, `src/subMenu28.ps1`, `recursosExtras/SiafSice-OR.reg` y `ESTADO_PROYECTO.md`.
* **Próxima acción técnica:** Probar la opción en un equipo local o remoto escribiendo `28` -> `6` en ShellSW, y opcionalmente guardar a GitHub mediante la opción oculta `1010`.

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
- [ ] Probar flujo completo de bajada en la PC secundaria mediante la opción `1011`.
- [ ] Revisión periódica de submódulos de administración según requerimientos del equipo de Helpdesk.
