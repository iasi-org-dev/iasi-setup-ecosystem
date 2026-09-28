# IASI PlantUML

Extensión Quarto que transforma bloques `.plantuml` en imágenes mediante un servidor PlantUML.

La extensión usa `POST`, integra la respuesta en el mediabag de Pandoc, conserva atributos de presentación y evita guardar en caché las imágenes de diagnóstico.

## Configuración

```yaml
filters:
  - iasi-plantuml

filter-options:
  plantuml:
    enabled: true
    server: http://javier:1025
    format: png
    cache: true
    styles: []
```
