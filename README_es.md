# IASI — Normativa corporativa aprobada v1.2.0

🇬🇧 [English](README.md) | 🇪🇸 **Español**

Paquete consolidado con **26 especificaciones `.iasi` atómicas y aprobadas**: conserva las 17 normas de v1.1.0 y añade 9 normas del ciclo de trabajo.

## Resumen

- **Codificación:** UTF-8 sin BOM; LF para fuentes multiplataforma y CRLF para scripts Windows; saltos físicos de línea.
- **Java:** camelCase, programación estructurada, descomposición funcional, formato de `if`, delegación de `switch`, máximo 60 líneas efectivas por método y 3 niveles de anidamiento.
- **Calidad:** complejidad ciclomática máxima 10 y cognitiva máxima 15 por función/método, respetando el analizador declarado.
- **Tecnología:** congelación de major.minor, aceptación controlada de parches, análisis previo al cambiar de línea y gestión continuada de vulnerabilidades.
- **Proceso:** `iasi/` gobierna; los resultados se generan exclusivamente en `outputs/<task-id>/` en la raíz del proyecto. Se separan temporales de compilación, candidatos y evidencias QA. Tras superar QA Gate y una promoción explícita manual o automática, el producto aprobado llega a `release/` sin trazas del proceso.
- **Especificaciones:** ámbitos corporate/departmental/project, documentos atómicos y consulta contextual.

Consulta `examples/repository-layout.txt`. Los archivos `.editorconfig`, `.gitattributes` y `.gitignore` son plantillas adaptables al proyecto y no sustituyen las comprobaciones.

**Para Codex:** esta línea base reemplaza las anteriores, y no se debe mezclar con ellas. No publicar ni promocionar sin autorización expresa.

No se ha modificado GitHub.
