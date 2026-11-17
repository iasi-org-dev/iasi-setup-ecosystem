# TASK-0002 — Application Return Codes

Las fuentes se mantienen en `../../src/` y el proyecto Maven en `../../pom.xml`.
Desde la raíz `software/iasi-setup-dev`, ejecutar:

```powershell
mvn -B -ntp clean verify
python outputs/TASK-0002/qa/tools/verify.py
```

| Ruta en esta tarea | Contenido |
| --- | --- |
| `build/target/` | Clases y productos intermedios reconstruibles |
| `build/rc-process-harness.jar` | Variante de prueba con entry point de QA; no es producto |
| `artifacts/iasi-setup-dev-0.1.0.jar` | Único artefacto candidato del producto |
| `qa/` | Pruebas, métricas, inventarios, logs y resultados de procesos |
| `qa-report.md` | Enlace al informe completo de aceptación técnica |

El gate comprueba además por hashes que TASK-0001, iasi y ambos árboles release
permanecen intactos. No se modifican aprobaciones ni especificaciones.

La especificación aplicable se localizó por su ID COR-MSG-RC-001, versión 0.1.1,
en `iasi/specifications/corporate/runtime/corporate-return-codes.iasi`. La tarea
todavía referencia `messages-return-codes.iasi`; esa discrepancia se informa sin
editar la norma ni el enunciado.
