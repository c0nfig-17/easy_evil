# Easy Evil — Evilginx2 Installer
**by c0nfig17 | [https://c0nfig17.com/](https://c0nfig17.com/)**

Script de instalación automatizada para [evilginx2](https://github.com/kgretzky/evilginx2) en sistemas Debian/Ubuntu.

---

## Requisitos

| Requisito | Detalle |
|-----------|---------|
| OS | Debian / Ubuntu (apt) |
| Arquitectura | x86_64 (amd64) |
| Acceso | root o sudo |
| RAM disponible | ≥ 1 GB |
| Disco libre | ≥ 3 GB en `/` |
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
- **RAM** — al menos 1 GB disponible en memoria.
- **Disco** — al menos 3 GB libres en `/`.
- **Puertos 22 y 443** — solo advierte si están ocupados, nunca los toca.
- **Puerto 53** — si está ocupado, para y deshabilita `systemd-resolved` automáticamente; si sigue ocupado tras eso, avisa para liberarlo a mano.
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
- Clona el repositorio en `/evilginx` (raíz del sistema de ficheros), o hace `git pull` si ya existe.
- Compila con `make`. El binario queda en `/evilginx/build/evilginx`.
- Aplica `chmod 700` al binario.

---

## Salida del script

| Prefijo | Significado |
|---------|-------------|
| `[+]` | Paso completado con éxito |
| `[*]` | Información / proceso en curso |
| `[!]` | Advertencia (pide confirmación si hay problemas en el checklist) |
| `[-]` | Error fatal — el script se detiene |

---

## Iniciar evilginx tras la instalación

```bash
# Reconectar a la sesión tmux (o crear una nueva: tmux new -s evilginx)
tmux a -t evilginx

# Dentro de tmux:
cd /evilginx/build
sudo ./evilginx -p ../phishlets/

# Para desconectarte sin detener el proceso: Ctrl+B, luego D
```

---

> **Hint:** Esta herramienta es para uso exclusivo en entornos **autorizados** (pentesting, red team, CTF, investigación de seguridad). El uso no autorizado contra sistemas ajenos es ilegal.
