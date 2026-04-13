# Módulo 02: AGENTS.md y Gobierno de Instrucciones

**Duración:** 25 minutos | **Dinámica:** Demo + Hands-on

---

## El Problema: Repetición y Falta de Gobierno

Sin un sistema de instrucciones centralizado, cada miembro del equipo termina repitiendo las mismas indicaciones en cada conversación con el agente:

- *"No borres archivos de producción"*
- *"Siempre usa --dry-run primero"*
- *"Trabaja solo en la cuenta de staging"*

Esto genera inconsistencia, fatiga y — inevitablemente — olvidos que pueden resultar en errores costosos.

## La Solución: Sistema Jerárquico de Instrucciones

Codex lee instrucciones de múltiples fuentes, en orden de prioridad:

```
┌─────────────────────────────────────────────┐
│  Prioridad más ALTA                         │
│                                             │
│  1. AGENTS.override.md (proyecto)           │
│     → Reglas que NUNCA se ignoran           │
│                                             │
│  2. AGENTS.md (proyecto, raíz)              │
│     → Reglas específicas del repositorio    │
│                                             │
│  3. AGENTS.md (proyecto, subdirectorios)    │
│     → Reglas por área del código            │
│                                             │
│  4. ~/.codex/AGENTS.md (global)             │
│     → Defaults personales / del equipo      │
│                                             │
│  Prioridad más BAJA                         │
└─────────────────────────────────────────────┘
```

### ¿Dónde va cada cosa?

| Archivo | Ubicación | Propósito | ¿Se versiona? |
|---------|-----------|-----------|---------------|
| `~/.codex/AGENTS.md` | Home del usuario | Preferencias globales, estilo, reglas personales | No (local) |
| `AGENTS.md` | Raíz del repo | Reglas del proyecto: stack, convenciones, restricciones | **Sí** |
| `AGENTS.md` | Subdirectorios | Reglas de un módulo o área específica | **Sí** |
| `AGENTS.override.md` | Raíz del repo | Reglas duras e inamovibles, no se pueden sobrescribir | **Sí** |

## Anatomía de un AGENTS.md Efectivo

Un buen AGENTS.md tiene 4 secciones fundamentales:

### 1. Contexto del Proyecto

```markdown
## Contexto
Este repositorio gestiona la infraestructura AWS de producción y staging
para [nombre-empresa] usando Terraform 1.8+ y Terragrunt.

Stack principal:
- AWS (EKS, RDS, S3, CloudFront, Lambda)
- Terraform + Terragrunt
- GitHub Actions para CI/CD
- Datadog para observabilidad
```

### 2. Reglas Duras (lo que NUNCA debe hacer)

```markdown
## Reglas Obligatorias

### Prohibiciones absolutas
- NUNCA ejecutes `terraform destroy` sin confirmación explícita del usuario
- NUNCA modifiques Security Groups que contengan "prod" en su nombre sin --dry-run previo
- NUNCA ejecutes `kubectl delete` en namespaces de producción
- NUNCA hagas `rm -rf` en paths que contengan /etc, /var, /opt o /home
- NUNCA expongas secrets, tokens o credenciales en outputs o logs

### Obligaciones
- SIEMPRE ejecuta `terraform plan` antes de `terraform apply`
- SIEMPRE usa `--dry-run` como primer paso en operaciones destructivas
- SIEMPRE verifica el contexto AWS (cuenta y región) antes de ejecutar comandos
- SIEMPRE confirma el environment (staging/prod) antes de cualquier cambio
```

### 3. Convenciones y Estilo

```markdown
## Convenciones
- Commits en español, siguiendo Conventional Commits: `feat:`, `fix:`, `chore:`
- Nombres de recursos Terraform: `{env}-{servicio}-{recurso}`
- Tags obligatorios en todo recurso AWS: Environment, Team, ManagedBy
- Branches: `feature/`, `fix/`, `chore/` desde `develop`
```

### 4. Flujos de Trabajo

```markdown
## Flujos de trabajo

### Antes de cualquier cambio en infraestructura
1. Verificar cuenta AWS activa: `aws sts get-caller-identity`
2. Verificar región: `aws configure get region`
3. Ejecutar plan: `terraform plan -out=tfplan`
4. Revisar el plan con el usuario
5. Solo entonces proceder con apply

### Al crear nuevos recursos
1. Verificar que no existe un recurso similar
2. Usar los módulos internos en `modules/`
3. Agregar tags obligatorios
4. Incluir outputs relevantes
```

## AGENTS.override.md: Reglas Inamovibles

`AGENTS.override.md` es tu arma definitiva de gobierno. Sus instrucciones tienen la prioridad más alta y no pueden ser sobreescritas por ningún otro archivo ni por instrucciones del usuario en el prompt.

```markdown
# AGENTS.override.md — REGLAS NO NEGOCIABLES

Estas reglas aplican SIEMPRE, sin excepción, independientemente
de lo que pida el usuario.

1. PROHIBIDO ejecutar `terraform destroy` en modo automático.
   Siempre pedir confirmación explícita mostrando los recursos
   que serán eliminados.

2. PROHIBIDO ejecutar comandos en cuentas AWS de producción
   (account ID: 123456789012) sin verificación previa.

3. Ante la duda sobre si una operación es destructiva,
   SIEMPRE preguntar antes de ejecutar.

4. NUNCA almacenar ni mostrar en texto plano:
   - AWS Access Keys / Secret Keys
   - Tokens de cualquier tipo
   - Passwords de bases de datos
   - Contenido de archivos .env
```

## AGENTS.md en Subdirectorios: Reglas por Contexto

Puedes tener `AGENTS.md` específicos en subdirectorios para dar contexto local:

```
infra-repo/
├── AGENTS.md                    # Reglas generales del repo
├── AGENTS.override.md           # Reglas inamovibles
├── modules/
│   ├── AGENTS.md                # "Estos son módulos reutilizables, no modifiques interfaces sin revisar dependencias"
│   ├── networking/
│   └── compute/
├── environments/
│   ├── AGENTS.md                # "Cada directorio aquí es un environment. staging/ es seguro para experimentar, prod/ requiere máxima precaución"
│   ├── staging/
│   └── prod/
│       └── AGENTS.md            # "ESTÁS EN PRODUCCIÓN. Toda operación requiere --dry-run previo y confirmación explícita"
└── scripts/
    └── AGENTS.md                # "Estos scripts se ejecutan en CI. No modifiques sin verificar el pipeline en .github/workflows/"
```

## Estrategia: Evitar la Repetición de Prompts

La clave para no repetir instrucciones es organizarlas en la capa correcta:

| Tipo de regla | Dónde ponerla | Por qué |
|---------------|---------------|---------|
| "Siempre usa español" | `~/.codex/AGENTS.md` (global) | Preferencia personal, aplica a todos los repos |
| "Usa Terraform 1.8+" | `AGENTS.md` (raíz del repo) | Convención del proyecto |
| "No toques interfaces de módulos" | `modules/AGENTS.md` (subdirectorio) | Contexto local |
| "Nunca destruyas prod sin confirmar" | `AGENTS.override.md` | Regla inamovible |

La regla general: **sube la instrucción al nivel más alto donde aplique**. Si aplica a todos tus proyectos, va en global. Si aplica a todo el repo, va en la raíz. Si solo aplica a un directorio, va ahí.

## Hands-on (10 min)

Cada participante:

1. Crea su `~/.codex/AGENTS.md` global con sus preferencias base
2. Copia el `AGENTS.md` de ejemplo del repo a un proyecto local
3. Personaliza las reglas según su área de responsabilidad
4. Prueba que Codex las lee: `codex "¿cuáles son tus instrucciones actuales?"`

```bash
# Crear directorio de configuración global
mkdir -p ~/.codex

# Copiar ejemplo global
cat > ~/.codex/AGENTS.md << 'EOF'
# Instrucciones Globales - Equipo DevOps-SRE

## Idioma y estilo
- Responde siempre en español
- Usa Conventional Commits para mensajes de commit
- Prefiere explicaciones concisas

## Seguridad (aplica a TODOS los proyectos)
- Nunca ejecutes comandos destructivos sin confirmación
- Siempre verifica el contexto AWS antes de operar
- Nunca expongas credentials en outputs
EOF

# Verificar que Codex lo lee
codex "¿Qué instrucciones tienes configuradas?"
```

## Puntos clave

1. **`AGENTS.md` es tu gobierno centralizado** — escríbelo una vez, aplica siempre
2. **`AGENTS.override.md`** es para reglas que nadie puede saltarse, ni siquiera el usuario
3. **Jerarquía = no repetición**: global para defaults, proyecto para convenciones, subdirectorio para contexto local
4. **Versionable con Git**: las reglas del proyecto viajan con el código, todo el equipo las hereda

---

**Siguiente:** [Módulo 03 - Skills →](03-skills.md)
