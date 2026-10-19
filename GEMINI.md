# Reglas y Guía de Proyecto para Antigravity: shellWil

## Descripción General
`shellWil` es una suite de administración, soporte técnico y mantenimiento de sistemas operativos Windows para entornos corporativos y Helpdesk.

* **Arquitectura:** Modular en `src/` ([helpers.ps1](src/helpers.ps1), [menuPrincipal.ps1](src/menuPrincipal.ps1), `subMenu20.ps1` a `subMenu28.ps1`), compilado con [build.ps1](build.ps1) en el binario [ShellSW.bat](ShellSW.bat).
* **Control de Versiones Multi-PC:**
  - **Opción 1011 (Oculta):** Sincronizar y continuar tras una pausa (`git pull origin main`, auto-resolución de locks/cambios pendientes, y auto-compilación con `build.ps1`).
  - **Opción 1010 (Oculta):** Guardar y publicar cambios a GitHub (`git add`, `git commit`, `git push`, y auto-rebase si el remoto está adelantado).
  - Ambas opciones se mantienen **ocultas** en el menú de la consola por seguridad.

---

## Memoria de Continuidad: Protocolo para "RECUERDAME"
Cuando el usuario o cualquier miembro de su equipo mencione las palabras clave:
* **"RECUERDAME"** (o en minúsculas "recuerdame")
* *"¿En qué parte nos quedamos?"*
* *"¿Dónde continuamos?"*
* *"¿Cuál es el estado del proyecto?"*

El asistente AI **debe**:
1. Consultar inmediatamente el archivo [ESTADO_PROYECTO.md](ESTADO_PROYECTO.md).
2. Responder de forma estructurada, ejecutiva y amigable indicando:
   - **Último hito completado** y fecha.
   - **Punto exacto actual** donde se pausó el trabajo.
   - **Pasos inmediatos para continuar** (especialmente si están iniciando en otra PC mediante la opción `1011`).
   - **Tareas pendientes prioritarias**.
3. Mantener actualizado [ESTADO_PROYECTO.md](ESTADO_PROYECTO.md) cada vez que se agregue o modifique una característica importante del proyecto.
