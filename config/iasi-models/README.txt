Copy the three files from services/ to the corresponding services/ folder in your IASI-Models project.
The Compose service must declare runtime: nvidia and gpus: all (already changed in your working project).
Flow: activate-gpu.sh -> nvidia-smi -> setup-nvidia-container.sh -> docker compose up -d.
The NVIDIA toolkit installer is re-runnable: if installed, keeps its version; if the Docker runtime already exists, avoids restarting Docker.
Requires Internet and apt repository access on first installation. No automatic OS reboot.
Validation: shell syntax checked; NOT tested on your Legion VM.
