IASI-Models | despliegue completo

1. ps/common/gpu.ps1 prepara services/gpu/{drivers,lib,wsl} en Windows.
2. Hyper-V e ISO ejecutan la instalacion de Ubuntu y Docker.
3. setup-gpu.sh copia sin aplanar las tres fuentes al Ubuntu destino.
4. cloud-init ejecuta /opt/iasi/iasi-deploy.sh una vez en el primer arranque.
5. iasi-deploy.sh activa GPU-P, comprueba /dev/dxg y nvidia-smi,
   ejecuta setup-nvidia.sh y despues levanta Ollama mediante Docker Compose.
6. setup-nvidia.sh instala/configura NVIDIA Container Toolkit y el runtime de Docker.

Reejecucion manual: sudo sh /opt/iasi/iasi-deploy.sh
Verificaciones: docker info --format '{{json .Runtimes}}'; docker ps;
  docker exec iasi-ollama ollama ps

Este ZIP no incluye drivers GPU ni modelos: los recopila la instalacion desde Legion.
No se ha probado una recreacion completa con este paquete: validar en Legion.
