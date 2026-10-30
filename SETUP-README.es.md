# Aprovisionamiento IASI: contrato actual

`setup.ps1` lee `config/setup.toml` y ejecuta los componentes declarados en orden:
primero `iasi-net.ps1`, después `hyper-v.ps1` para cada máquina seleccionada.

```powershell
.\bin\ps\setup.ps1 --config .\config --path C:\Maquinas -f
```

- Sin `-f`: conserva las VM existentes y crea las que faltan. No cambia el estado de una VM existente.
- Con `-f`: recrea los recursos seleccionados, incluidos red, VM y discos virtuales. Las VM recreadas quedan **apagadas**.
- El aprovisionamiento **no arranca ninguna máquina** ni espera ENTER, instalación del invitado, servicios o paquetes.
- En el primer arranque manual de cada VM se ejecutará el proceso de instalación preparado para esa máquina.
- La comprobación/ejecución de la instalación del invitado pertenece al ciclo de vida de la VM, no a este comando.
- `-l` se acepta por compatibilidad, pero ya no es necesario: las VM nuevas siempre quedan apagadas.

La recreación de la red puede fallar si hay VM encendidas conectadas a ella. Apágalas antes de ejecutar `-f`.

**Sin pruebas de ejecución real en el host Windows/Hyper-V:** solo validación estática de esta entrega.
