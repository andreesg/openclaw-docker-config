

# Configuración de Docker para OpenClaw

Configuración de Docker y configuración de la aplicación para OpenClaw. Repositorio complementario de [openclaw-terraform-hetzner](https://github.com/andreesg/openclaw-terraform-hetzner).

**Nota:** Esta es una configuración mínima y genérica con solo las habilidades esenciales activadas. Se anima a personalizarla agregando [habilidades de ClawHub](https://clawhub.ai/) o creando tus propias habilidades personalizadas (ver [Trabajar con Habilidades](#working-with-skills)).

```
┌──────────────┐                        ┌──────────────────────┐
│   Laptop     │──── git push ─────────▶│   GitHub             │
│   (develop)  │                        │   (openclaw-config)  │
│              │                        └──────────────────────┘
│              │  
│              │   build-and-push.sh    ┌──────────────────────┐
│              │───────────────────────▶│   GHCR               │
│              │                        │   :latest  :abc1234  │
│              │                        └──────────────────────┘
│              │
│              │  make push-config      ┌──────────────────────┐
│              │  make push-env         │   Hetzner VPS        │
│              │──── (infra repo) ─────▶│   ┌────────────────┐ │
│              │  make deploy           │   │ Docker         │ │
└──────────────┘                        │   │ openclaw-gw    │ │
                                        │   └────────────────┘ │
                                        │   :18789 (loopback)  │
                                        └──────────────────────┘
```

## Requisitos previos

- Docker y Docker Compose en el VPS
- Acceso SSH al VPS (`ssh openclaw@VPS_IP`)
- El repositorio de infraestructura (`openclaw-terraform-hetzner`) configurado con `config/inputs.sh` apuntando `CONFIG_DIR` a este repositorio
- Claves API (ver `docker/.env.example` para la lista completa; los secretos se encuentran en `secrets/openclaw.env` del repositorio de infraestructura)

## Cómo se conecta este repositorio al VPS

Este repositorio **no se clona en el VPS**. En su lugar, los scripts del repositorio de infraestructura copian archivos específicos de tu clon local al VPS:

| Elemento | Enviado por | Destino en el VPS |
|----------|--------------|-------------------|
| `docker/docker-compose.yml` | `make bootstrap` (una vez) | `~/openclaw/docker-compose.yml` |
| `config/*` (openclaw.json, etc.) | `make push-config` | `~/.openclaw/` |
| Imagen de Docker | `make deploy` (extrae de GHCR) | Caché de imágenes de Docker |
| Secretos | `make push-env` | `~/openclaw/.env` |

## Configuración inicial

> El aprovisionamiento y la inicialización están gestionados por el repositorio de infraestructura. Consulta su README.

1. **En el repositorio de infraestructura**, establece `CONFIG_DIR` en `config/inputs.sh` para que apunte al directorio de este repositorio
2. **Inicia sesión en GHCR** (una sola vez, en tu portátil):
   ```bash
   echo "$GHCR_TOKEN" | docker login ghcr.io -u $GHCR_USERNAME --password-stdin
   ```
3. **Construye y envía la imagen de Docker**:
   ```bash
   bash scripts/build-and-push.sh
   ```
4. Ejecuta `make bootstrap` desde el repositorio de infraestructura: copia `docker-compose.yml`, la configuración y los secretos al VPS
5. Ejecuta `make deploy` desde el repositorio de infraestructura: extrae la imagen de Docker desde GHCR e inicia el contenedor
6. **Completa el emparejamiento de Telegram:** abre Telegram, busca tu bot y envía `/start`

## Flujo de trabajo para cambios de configuración

Existen dos tipos de cambios y tienen flujos de trabajo diferentes:

### Modificar la configuración (openclaw.json, habilidades, hooks)

Los archivos de configuración se envían al VPS mediante SCP; no es necesario reconstruir la imagen.

```
edit → validate → commit → push → make push-config (infra repo)
```

1. Edita los archivos en `config/`, `skills/` o `hooks/`
2. Valida: `bash scripts/validate-config.sh`
3. Confirma y envía a GitHub
4. Desde el **repositorio de infraestructura**: `make push-config` (envía la configuración al VPS vía SCP y reinicia)

### Modificar la imagen de Docker (Dockerfile, versión de OpenClaw)

Los cambios en la imagen requieren una reconstrucción y envío a GHCR.

```
edit → commit → push → build-and-push.sh → make deploy (infra repo)
```

1. Edita `docker/Dockerfile` (por ejemplo, actualiza `OPENCLAW_VERSION`, añade un binario)
2. Confirma y envía a GitHub
3. Construye y envía la imagen: `bash scripts/build-and-push.sh`
4. Desde el **repositorio de infraestructura**: `make deploy` (extrae la nueva imagen de GHCR y reinicia)

## Trabajar con Habilidades

Este repositorio incluye un conjunto mínimo de habilidades genéricas en `config/skills-manifest.txt`. Puedes extender OpenClaw agregando habilidades de ClawHub o creando habilidades personalizadas.

### Habilidades de ClawHub

[ClawHub](https://clawhub.ai/) es el registro de habilidades de la comunidad para OpenClaw. Para agregar una habilidad de ClawHub:

1. **Busca la habilidad** en [clawhub.ai](https://clawhub.ai/) (por ejemplo, `pdf`, `ms-office-suite`, `jira`)
2. **Añade al manifiesto**: Edita `config/skills-manifest.txt` y agrega el nombre de la habilidad
   ```
   # PDF processing
   pdf
   ```
3. **Reconstruye e implementa**:
   ```bash
   bash scripts/build-and-push.sh
   # Luego desde el repositorio de infraestructura:
   make deploy
   ```

El script `entrypoint.sh` instala automáticamente las habilidades del manifiesto al iniciar el contenedor mediante `clawhub install`.

### Habilidades Personalizadas

Las habilidades personalizadas son comandos o flujos de trabajo definidos por el usuario. Para crear una:

1. **Crea el directorio de la habilidad**:
   ```bash
   mkdir -p skills/my-skill
   ```

2. **Escribe el manifiesto de la habilidad** (`skills/my-skill/skill.json`):
   ```json
   {
     "name": "my-skill",
     "version": "1.0.0",
     "description": "My custom skill",
     "commands": {
       "my-command": {
         "handler": "my-command.sh"
       }
     }
   }
   ```

3. **Escribe el controlador** (`skills/my-skill/my-command.sh`):
   ```bash
   #!/bin/bash
   # Your custom logic here
   echo "Hello from my-skill!"
   ```

4. **Hazlo ejecutable**:
   ```bash
   chmod +x skills/my-skill/my-command.sh
   ```

5. **Envía al VPS**:
   ```bash
   # Desde el repositorio de infraestructura:
   make push-config
   ```

   Las habilidades personalizadas en `skills/` se copian a `~/.openclaw/workspace/skills/` en el VPS.

6. **Usa en OpenClaw**:
   - Vía chat: "Ejecuta my-command"
   - Vía Telegram: `/my-command`

### Referencia de Estructura de Habilidades

Las habilidades de OpenClaw pueden incluir:
- **Comandos con barra (/)** — invocables mediante `/command-name`
- **Ganchos (Hooks)** — activados por eventos (por ejemplo, antes de la ejecución de una herramienta)
- **Plantillas** — plantillas de prompts para flujos de trabajo comunes
- **Herramientas** — definiciones de herramientas personalizadas

Para documentación detallada sobre desarrollo de habilidades, consulta la [Guía de Desarrollo de Habilidades de OpenClaw](https://docs.openclaw.ai/skills).

### Habilidades Incluidas

La configuración predeterminada incluye estas habilidades genéricas de ClawHub:

| Habilidad | Descripción | Caso de uso |
|-----------|-------------|-------------|
| `yt` | Obtención de transcripciones de YouTube y búsqueda de videos | "Obtén la transcripción de youtube.com/watch?v=..." |
| `agent-browser` | Navegador sin cabeza para páginas con mucho JavaScript o de acceso restringido | Acceder a contenido dinámico |
| `system-monitor` | Verificación de estado de CPU/RAM/GPU | "¿Cuál es el uso de CPU de mi servidor?" |
| `conventional-commits` | Formato de mensajes de commit según convención | Mensajes de commit estandarizados |

Están intencionalmente mínimas; agrega tus propias habilidades según tus flujos de trabajo.

## Sincronización Git del Espacio de Trabajo (Opcional)

Realiza copias de seguridad automáticas de tu directorio `~/.openclaw/workspace` en un remoto git privado. Se ejecuta como un contenedor sidecar de Docker con cron integrado, enviando cambios a una rama configurable (predeterminada: `auto`). Luego, puedes fusionar manualmente `auto` en `main` a través de un PR cuando quieras.

Es compatible con GitHub, GitLab, Bitbucket y cualquier remoto git que acepte envío HTTPS con autenticación en línea.

### Configuración

Elige **una** de las dos opciones a continuación; no establezcas ambas.

#### Opción 1: Abreviatura de GitHub

1. **Crea un repositorio privado de GitHub** (por ejemplo, `your-username/openclaw-workspace`)
2. **Crea un PAT de GitHub** en [github.com/settings/tokens](https://github.com/settings/tokens) con alcance `repo`
3. **Añade a tu `.env`** (o a `secrets/openclaw.env` del repositorio de infraestructura):
   ```
   GIT_WORKSPACE_REPO=your-username/openclaw-workspace
   GIT_WORKSPACE_TOKEN=ghp_your_personal_access_token
   ```

El token se pasa a git mediante `GIT_ASKPASS` en tiempo de ejecución y **no** se incrusta en la URL remota ni se persiste en `.git/config`.

#### Opción 2: Remoto genérico de git

1. **Construye la URL remota** con autenticación en línea para tu proveedor:
   - GitLab: `https://user:token@gitlab.com/username/repo.git`
   - Bitbucket: `https://x-token-auth:token@bitbucket.org/username/repo.git`
2. **Añade a tu `.env`** (o a `secrets/openclaw.env` del repositorio de infraestructura):
   ```
   GIT_WORKSPACE_REMOTE=https://user:token@gitlab.com/username/openclaw-workspace.git
   ```

> **Nota:** Con esta opción, la URL (incluidas las credenciales) se almacena en `.git/config` dentro del volumen del espacio de trabajo. El token ya está presente en el archivo `.env` del VPS, por lo que esto no aumenta la superficie de ataque.

#### Configuración común (ambas opciones)

```
GIT_WORKSPACE_BRANCH=auto
GIT_WORKSPACE_SYNC_SCHEDULE=0 4 * * *
```

**Implementación** — el sidecar se habilita automáticamente cuando se establece `GIT_WORKSPACE_REPO` o `GIT_WORKSPACE_REMOTE`:
```bash
# Desde el repositorio de infraestructura:
make push-env && make deploy
```

El sidecar ejecuta una sincronización inicial al arrancar y luego sincroniza según la programación de cron configurada (predeterminada: diario a las 4:00 AM UTC).

### Sincronización Manual

```bash
# Desde el repositorio de infraestructura:
make workspace-sync
```

### Deshabilitar

Elimina o limpia `GIT_WORKSPACE_REPO` / `GIT_WORKSPACE_REMOTE` de tu `.env` y vuelve a implementar.

## Acceso al Panel de Control

El gateway se vincula solo a loopback (`127.0.0.1:18789`). Accede a él mediante un túnel SSH:

```bash
ssh -N -L 18789:127.0.0.1:18789 openclaw@VPS_IP
```

Luego abre `http://localhost:18789` en tu navegador.

## Gestión de Secretos

Los secretos (claves API, tokens) son gestionados por el **repositorio de infraestructura**, no por este repositorio.
Este repositorio solo contiene `docker/.env.example` como documentación de las variables requeridas.

En el repositorio de infraestructura:
- Edita `secrets/openclaw.env`
- Ejecuta `make push-env` para enviar al VPS y reiniciar

## Versionado de Imágenes de Docker

Las imágenes se construyen localmente y se envían a GHCR mediante `scripts/build-and-push.sh`:

- `ghcr.io/YOUR_USERNAME/openclaw-docker-config/openclaw-gateway:latest` — imagen principal del gateway
- `ghcr.io/YOUR_USERNAME/openclaw-docker-config/workspace-sync:latest` — sidecar de sincronización git del espacio de trabajo
- Ambas imágenes también reciben una etiqueta `:<sha>` vinculada al commit de git

**Inicio de sesión único en GHCR (portátil):**

```bash
# Crea un PAT en github.com/settings/tokens con alcance write:packages
echo "$GH_TOKEN" | docker login ghcr.io -u $GHCR_USERNAME --password-stdin
```

**Restaurar una versión anterior:**

```bash
# En el VPS, en ~/openclaw/:
# Edita docker-compose.yml, cambia :latest por la etiqueta SHA (por ejemplo, :abc1234)
docker compose pull && docker compose up -d
```

**Actualizar OpenClaw:** actualiza `OPENCLAW_VERSION` en `docker/Dockerfile`, confirma, envía y luego ejecuta `scripts/build-and-push.sh` seguido de `make deploy` desde el repositorio de infraestructura.

## Solución de Problemas

### El contenedor no inicia

```bash
# Desde el repositorio de infraestructura:
make logs
# O inicia sesión mediante SSH:
cd ~/openclaw && docker compose logs openclaw-gateway
```

Verifica si faltan variables de entorno o si el JSON de configuración es inválido.

### "Permiso denegado" en el directorio de configuración

Asegúrate de que los directorios del host existan y pertenezcan al usuario correcto:

```bash
sudo mkdir -p /home/openclaw/.openclaw/workspace
sudo chown -R 1000:1000 /home/openclaw/.openclaw
```

### El bot de Telegram no responde

- Verifica secretos: `make push-env` desde el repositorio de infraestructura para reenviar
- Verifica que ningún otro proceso esté consultando el mismo token del bot
- Reinicia: `make deploy` desde el repositorio de infraestructura

### La validación de la configuración falla

```bash
bash scripts/validate-config.sh
```

Causas comunes:
- Sintaxis JSON inválida (coma faltante, coma final)
- Clave API en texto plano pegada accidentalmente en `openclaw.json`

### Verificar estado del VPS

```bash
# Desde el repositorio de infraestructura:
make status
```

## Habilitar Ganchos de Git

Para activar el gancho de validación pre-commit:

```bash
git config core.hooksPath .githooks
```
