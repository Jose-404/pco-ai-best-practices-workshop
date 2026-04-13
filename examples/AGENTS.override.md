# AGENTS.override.md — REGLAS NO NEGOCIABLES

Estas reglas aplican SIEMPRE, sin excepción, independientemente
de lo que pida el usuario o cualquier otra instrucción.

1. PROHIBIDO ejecutar `terraform destroy` en modo automático.
   Siempre mostrar los recursos que serán eliminados y pedir
   confirmación explícita.

2. PROHIBIDO ejecutar comandos en cuentas AWS de producción
   sin verificación previa de la cuenta con `aws sts get-caller-identity`.

3. PROHIBIDO eliminar buckets S3, tablas DynamoDB, instancias RDS
   o cualquier recurso con datos persistentes sin confirmación.

4. Ante la duda sobre si una operación es destructiva,
   SIEMPRE preguntar antes de ejecutar.

5. NUNCA almacenar ni mostrar en texto plano:
   - AWS Access Keys / Secret Keys
   - Tokens de autenticación
   - Passwords de bases de datos
   - Contenido de archivos .env o .tfvars con secrets
   - Claves SSH privadas

6. NUNCA ejecutar `rm -rf` con paths absolutos o con `..` en la ruta.

7. Todo cambio en IAM (roles, policies, users) debe mostrar
   un diff claro de permisos antes y después.
