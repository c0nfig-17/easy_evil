# easy_evil — Evilginx2 Installer

Script de instalación automatizada para [evilginx2](https://github.com/kgretzky/evilginx2) en sistemas Debian/Ubuntu.

---

## Requisitos

| Requisito | Detalle |
|-----------|---------|
| OS | Debian / Ubuntu (apt) |
| Arquitectura | x86_64 (amd64) |
| Acceso | root o sudo |
| Disco libre | ≥ 1 GB |
| Puertos libres | 22, 53, 443 |

---

## Uso rápido

```bash
chmod +x install.sh
sudo ./install.sh
```

---

## Qué hace el script

### Checklist previo
Antes de instalar, verifica automáticamente:
- **Disco** — al menos 1 GB disponible.
- **Puertos** — 22, 53 y 443 libres.
- **Usuario sudo con SSH** — usuario no-root en el grupo `sudo`/`wheel` con `authorized_keys` configurado para login sin contraseña.

Si alguna comprobación falla, se muestra una advertencia y se solicita confirmación para continuar.

### Paso 1 — Paquetes del sistema
Actualiza los repositorios e instala:
`git` · `curl` · `make` · `tmux`

### Paso 2 — Go 1.22.3
- Elimina cualquier versión anterior de Go en `/usr/local/go`.
- Descarga e instala Go 1.22.3 desde `go.dev`.
- Añade `/usr/local/go/bin` al `PATH` en `/etc/profile.d/golang.sh` y en el `.bashrc` del usuario.

### Paso 3 — Node.js 18 (vía nvm)
- Instala **nvm v0.39.7**.
- Instala y fija **Node.js 18** como versión por defecto.

### Paso 4 — Evilginx2
- Clona el repositorio en `/evilginx` (o hace `git pull` si ya existe).
- Compila con `make`.

---

## Salida del script

El script usa los siguientes prefijos:

| Prefijo | Significado |
|---------|-------------|
| `[+]` | Paso completado con éxito |
| `[*]` | Información / proceso en curso |
| `[!]` | Advertencia (no bloquea, salvo errores graves) |
| `[-]` | Error fatal — el script se detiene |

---

## Iniciar evilginx tras la instalación

```bash
# Abre una sesión tmux para dejar evilginx corriendo en segundo plano
tmux new -s evilginx

# Dentro de tmux:
sudo /evilginx/evilginx -p /evilginx/phishlets

# Para desconectarte sin detener el proceso: Ctrl+B, luego D
# Para volver a la sesión: tmux attach -t evilginx
```

---

## Aviso legal

Esta herramienta es para uso exclusivo en entornos **autorizados** (pentesting, red team, CTF, investigación de seguridad).
El uso no autorizado contra sistemas ajenos es ilegal.
