# IASI Setup Ecosystem: Caso de negocio

**Tipo de documento:** Entrada externa. Idea y justificación inicial del proyecto.  
**Estado:** Propuesta inicial para revisión.  
**Proyecto:** `iasi-setup-ecosystem`.

## 1. Contexto de la iniciativa

IASI es una iniciativa de ingeniería que reúne una metodología, un método de trabajo y un ecosistema de herramientas y recursos reutilizables. Su finalidad es facilitar el desarrollo de soluciones justificables, verificables y capaces de evolucionar. Una parte importante de su filosofía consiste en preservar y reutilizar el diseño: arquitecturas, arquetipos, contratos y mecanismos generales que admiten realizaciones tecnológicas diferentes. El documento *IASI: Filosofía y fundamentos* desarrolla este marco conceptual.

IASI necesita, además, un entorno donde desarrollar sus propios componentes. Ese entorno no se reduce a un editor o a un compilador. Incluye sistemas operativos, herramientas, repositorios, servicios de apoyo, configuraciones, relaciones entre componentes y, cuando resulta necesario, máquinas virtuales. En la práctica, todo ello forma una infraestructura de ingeniería cuyo comportamiento depende de múltiples decisiones que deben poder conocerse y comprobarse.

Actualmente disponemos de una implementación concreta de ese entorno, construida sobre el equipo Legion y varias máquinas virtuales. Esta experiencia proporciona una referencia real y funcional, pero también ha puesto de manifiesto una necesidad: la capacidad de reconstruir y evolucionar el entorno no debería depender de recordar cómo se realizaron instalaciones anteriores ni de conservar indefinidamente el estado de un conjunto particular de máquinas.

## 2. Necesidad que se pretende atender

La preparación de un entorno de ingeniería puede acabar convirtiéndose en un proceso artesanal. Las herramientas se instalan en momentos distintos, la configuración se distribuye entre numerosos archivos, algunas dependencias permanecen implícitas y ciertas decisiones solo se conservan en la experiencia de quien realizó la instalación. Aunque el entorno funcione, reproducirlo en un equipo nuevo, recuperarlo tras una incidencia o modificarlo con confianza se vuelve más difícil de lo necesario.

Esta situación resulta especialmente relevante para IASI. Un ecosistema que promueve la trazabilidad y la reproducibilidad debe poder aplicar esos principios a su propia infraestructura de desarrollo. No basta con conservar una imagen de las máquinas existentes: necesitamos conocer qué constituye el entorno, qué componentes son necesarios, cómo se relacionan y qué condiciones permiten afirmar que está listo para trabajar.

La necesidad no se limita, sin embargo, a recuperar nuestra configuración actual. Automatizar exclusivamente el estado de Legion resolvería un problema inmediato, pero podría producir una solución demasiado ligada a sus sistemas y herramientas. El proyecto debe atender también una necesidad más general: disponer de una base que permita definir y construir entornos diferentes, conservando las propiedades de modularidad, extensibilidad y verificación.

## 3. Oportunidad de ingeniería

La reconstrucción del entorno IASI constituye un primer caso de aplicación suficientemente concreto para desarrollar y comprobar una solución real. Conocemos sus componentes principales, contamos con experiencias previas de instalación y podemos contrastar el resultado con las capacidades que necesitamos para desarrollar el ecosistema. Esta circunstancia permite avanzar de manera incremental y evaluar las decisiones con evidencias, en lugar de diseñar una plataforma puramente teórica.

Al mismo tiempo, el problema ofrece una oportunidad de crear una arquitectura reutilizable. La preparación de un entorno implica organizar responsabilidades, describir configuraciones, resolver dependencias, ejecutar operaciones y verificar resultados. Estas necesidades aparecen también en muchos otros escenarios de aprovisionamiento, despliegue y preparación de sistemas. Si se resuelven mediante un modelo arquitectónico claro, dicho modelo podrá adaptarse a finalidades diferentes, aunque varíen los lenguajes, las plataformas o las implementaciones internas.

El interés del proyecto no reside, por tanto, en acumular scripts de instalación ni en copiar una configuración determinada. Reside en desarrollar y contrastar una forma de organizar el problema que pueda convertirse en un recurso de ingeniería de IASI. La primera realización servirá para reconstruir nuestro entorno; las posteriores podrán aprovechar sus principios sin quedar obligadas a repetir nuestras elecciones tecnológicas.

## 4. Propósito y objetivos

**El propósito de `iasi-setup-ecosystem` es proporcionar una base modular, extensible, reproducible y verificable para definir, construir, reconstruir y evolucionar entornos de ingeniería.** Su primera aplicación será el entorno de desarrollo de la implementación de referencia de IASI, pero esta aplicación no establecerá los límites de validez del modelo.

El objetivo inmediato consiste en poder partir de una infraestructura anfitriona preparada y obtener un entorno de desarrollo IASI funcional, mediante un procedimiento definido que permita conocer las operaciones realizadas y comprobar sus resultados. El entorno deberá contemplar los componentes necesarios para trabajar, así como sus configuraciones y relaciones, sin depender de acciones no documentadas o conocimientos que no puedan transferirse.

El objetivo de evolución consiste en permitir modificaciones controladas: incorporar herramientas, sustituir componentes, ampliar capacidades y adaptar la organización del entorno sin rehacer por completo la solución. Una configuración concreta debe poder reproducirse, pero también debe poder cambiar. Ambas capacidades son esenciales y complementarias.

Finalmente, el proyecto pretende que las decisiones de arquitectura y los mecanismos generales que demuestren su utilidad puedan aprovecharse en otros contextos. Este objetivo se refiere a la **reutilización del diseño**, no a la obligación de compartir el mismo código o utilizar las mismas tecnologías. La arquitectura será útil cuando sus responsabilidades, contratos y posibilidades de extensión puedan aplicarse a nuevas necesidades de manera comprensible y verificable.

## 5. Enfoque inicial y alcance conceptual

El trabajo comenzará con la reconstrucción del entorno de desarrollo de IASI, tomando las instalaciones existentes como referencia y utilizando los recursos disponibles. Se podrán recuperar conocimientos y soluciones anteriores, pero el nuevo trabajo se planteará desde sus necesidades y objetivos, sin asumir que todas las decisiones históricas deban mantenerse.

En las primeras etapas se admitirán operaciones manuales junto a las automatizadas. La condición es que formen parte de un procedimiento explícito, sean comprensibles y permitan verificar sus resultados. La automatización se incorporará progresivamente allí donde simplifique el trabajo, reduzca errores o mejore la repetibilidad. No se considera necesario resolver desde el inicio todas las plataformas ni todos los casos de uso futuros.

Este documento expresa la necesidad y la intención del proyecto. No fija todavía requisitos detallados, contratos de software, estructura de módulos ni tecnologías de implementación. Esas decisiones deberán surgir del procedimiento de ingeniería posterior, con sus correspondientes alternativas, justificaciones y verificaciones.

## 6. Valor esperado y criterios de éxito

El primer valor esperado es operativo: disponer de un procedimiento fiable para preparar de nuevo un entorno de desarrollo IASI, recuperar sus capacidades esenciales y verificar que puede utilizarse. Esto reduce la dependencia del estado de máquinas concretas y facilita el mantenimiento y la evolución de la infraestructura.

El segundo valor es organizativo: transformar las instalaciones y configuraciones dispersas en conocimiento comprensible y transferible. Una persona que no haya preparado el entorno original debería poder conocer sus componentes, entender el proceso previsto y reconocer si el resultado satisface las condiciones establecidas.

El tercer valor es propiamente arquitectónico: obtener una base de solución cuya utilidad trascienda la reconstrucción de nuestro entorno. Si sus responsabilidades y mecanismos están bien definidos, podrá adaptarse a otros escenarios sin imponer la misma plataforma o el mismo código. Los elementos genuinamente generales podrán enriquecer el patrimonio reutilizable de IASI.

Consideraremos satisfactoria la primera aplicación cuando sea posible construir, mediante el procedimiento establecido, un entorno de desarrollo funcionalmente equivalente al de referencia y disponer de evidencias suficientes de su correcto funcionamiento. La evolución posterior se evaluará por la facilidad con que puedan introducirse cambios o nuevas realizaciones sin comprometer la coherencia de la solución.

## 7. Justificación final

`iasi-setup-ecosystem` responde a una necesidad concreta de IASI, pero su razón de ser no termina en reproducir un conjunto de máquinas. Es la oportunidad de convertir esa necesidad en un modelo de ingeniería reutilizable, desarrollado y verificado sobre un caso real.

La iniciativa permitirá aplicar IASI a uno de sus propios componentes y, al hacerlo, poner a prueba sus principios de diseño, reproducibilidad, extensibilidad y evolución. **Queremos reconstruir nuestro entorno de desarrollo, pero sobre todo queremos crear una base que permita construir otros entornos sin tener que empezar siempre desde cero.**
