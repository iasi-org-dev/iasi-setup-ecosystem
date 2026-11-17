# ERS-001 – Plataformas y virtualización

**Proyecto:** IASI-DEV  
**Clasificación:** Externals / Especificación de Requerimientos del Sistema  
**Identificador:** ERS-001  
**Estado:** Borrador para revisión

## 1. Objeto

El presente documento establece los requerimientos relativos a las plataformas de ejecución y las tecnologías de virtualización que deberá admitir el sistema.

Su finalidad es garantizar un planteamiento multiplataforma que permita utilizar el sistema en diferentes entornos informáticos, evitando su dependencia exclusiva de un sistema operativo, una arquitectura de hardware o una tecnología de virtualización determinada.

## 2. Soporte multiplataforma

El sistema deberá tener carácter multiplataforma y contemplar su utilización en diferentes sistemas operativos y arquitecturas informáticas.

Entre las plataformas que deberán considerarse se encuentran Microsoft Windows, GNU/Linux, macOS y otros entornos informáticos, incluidos sistemas de arquitectura IBM Z (zSeries).

Esta relación no constituye una lista cerrada. El sistema deberá admitir la incorporación progresiva de nuevas plataformas, de acuerdo con las necesidades y la evolución del proyecto.

En las primeras etapas, las plataformas prioritarias serán Microsoft Windows y GNU/Linux, tomando Ubuntu como distribución Linux de referencia.

Las capacidades fundamentales del sistema deberán mantenerse en las distintas plataformas soportadas, teniendo en cuenta sus características y limitaciones particulares.

## 3. Utilización de máquinas virtuales

El sistema deberá basarse en la utilización de máquinas virtuales como elemento fundamental para la creación y utilización de entornos de trabajo.

Estas máquinas virtuales permitirán disponer de entornos diferenciados, adaptados a las necesidades de los usuarios y de los proyectos que se desarrollen.

El sistema deberá contemplar diferentes configuraciones y características de máquinas virtuales, de acuerdo con las posibilidades de cada plataforma.

## 4. Tecnologías de virtualización

El sistema deberá contemplar diferentes tecnologías de virtualización, evitando establecer una dependencia exclusiva respecto de un fabricante, producto o solución concreta.

Entre las tecnologías que deberán considerarse se encuentran Microsoft Hyper-V, Oracle VirtualBox, VMware y KVM/QEMU, así como las soluciones de virtualización disponibles en otras plataformas.

Esta relación es orientativa y no constituye una lista cerrada. Deberá ser posible incorporar otras tecnologías conforme evolucionen las necesidades del proyecto.

La disponibilidad efectiva de cada tecnología dependerá de las características de la plataforma utilizada y de las capacidades implementadas en cada versión del sistema.

## 5. Evolución del soporte

Los requerimientos establecidos en este documento definen las capacidades exigidas al sistema, con independencia del momento en que se incorporen a sus distintas versiones.

Su implementación podrá realizarse progresivamente, de acuerdo con la planificación y evolución del proyecto, sin que ello modifique el carácter multiplataforma del sistema.

Cada versión deberá permitir identificar las plataformas y tecnologías de virtualización que efectivamente soporta, diferenciándolas de aquellas cuyo soporte se encuentre pendiente de implementación.

## 6. Alcance

El presente documento comprende los requerimientos relativos al soporte multiplataforma, la utilización de máquinas virtuales y la diversidad de tecnologías de virtualización que deberá admitir el sistema.

Quedan fuera de su alcance las decisiones relacionadas con los mecanismos específicos de instalación, configuración y administración, así como la selección de las soluciones técnicas necesarias para implementar estas capacidades.

Estas cuestiones se abordarán en las fases correspondientes de análisis y diseño o en otros documentos de requerimientos cuando proceda.