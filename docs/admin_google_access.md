# Acceso administrativo con Google

El panel solo muestra inicio de sesión con Google. Autenticarse no concede
permisos: `firestore.rules` y la aplicación requieren el custom claim
`admin: true`. Una cuenta sin ese claim ve **Acceso no autorizado** y no puede
leer ni modificar el banco.

## Configuración del proyecto Firebase

En **Authentication → Sign-in method**, habilita el proveedor **Google**.
Para desarrollo local, `localhost` está permitido por Firebase; antes de
publicar el panel en otro dominio, agréguelo a **Authentication → Settings →
Authorized domains**.

## Autorizar o retirar una cuenta

Primero la persona debe iniciar sesión una vez con Google, para que Firebase
Authentication cree su usuario. Después, desde una terminal autenticada con
credenciales de servidor para el proyecto correcto, ejecute desde `functions/`:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\ruta\segura\service-account.json'
$env:GCLOUD_PROJECT = 'ingresoya-e5115'
npm run admin:claim -- grant persona.autorizada@gmail.com
```

Para revocar el acceso:

```powershell
npm run admin:claim -- revoke persona.autorizada@gmail.com
```

El archivo de credenciales no se guarda en el repositorio. Tras conceder o
retirar el claim, la persona debe cerrar sesión y volver a entrar para obtener
un token actualizado.
