# TASK-00.01.03 — Context

Esta tarea evoluciona las fuentes existentes en `../../src/` y utiliza el
`../../pom.xml` del mismo proyecto. No crea otra copia independiente del software.

Desde la raíz `software/iasi-setup-dev`:

```powershell
mvn -B -ntp clean verify
python outputs/TASK-00.01.03/qa/tools/verify.py
```

El candidato está en artifacts/, los intermedios en build/target/ y las evidencias
en qa/. Las variantes con entry points de QA están únicamente en build/ y nunca
son artefactos candidatos. El informe completo está en qa/qa-report.md.

Se aplica COR-ARC-CTX-001 0.1.1 y COR-MSG-RC-001 0.1.5. El usuario ha confirmado
que la dependencia del enunciado se refiere a TASK-0002. Se conserva el ID nuevo
TASK-00.01.03 y la trazabilidad histórica, sin editar documentos ni estados.
