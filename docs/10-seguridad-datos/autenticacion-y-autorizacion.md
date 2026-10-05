# 🔐 Autenticación y Autorización

## 1. Objetivo
Establecer las políticas y controles de acceso para el ecosistema de **Fixia**, garantizando que la identidad de cada usuario y microservicio sea autenticada de manera segura y autorizada bajo el principio de menor privilegio.

---

## 2. Esquema de Autenticación (OAuth2 + JWT)

El flujo de autenticación centralizada es gestionado por `fixia-auth-service`.

```text
[ Cliente / Frontend ] ──1. Credentials──> [ fixia-auth-service ]
        │                                         │
        │<──2. JWT Access Token + Refresh Token───┘
        │
        └──3. Request + Bearer JWT──> [ API Gateway ] ──4. Validated Token──> [ Microservicio ]
```

---

## 3. Estructura del JWT Access Token

Los tokens JWT son firmados con la clave privada del servicio utilizando el algoritmo **RS256** (RSA Signature con SHA-256).

```json
{
  "iss": "https://auth.fixia.com",
  "sub": "usr_94821a0f-561b-42f8",
  "aud": "https://api.fixia.com",
  "exp": 1787860800,
  "iat": 1787857200,
  "roles": [
    "ROLE_PROFESSIONAL"
  ],
  "permissions": [
    "orders:read",
    "orders:accept",
    "payments:withdraw"
  ]
}
```

---

## 4. Control de Acceso Basado en Roles (RBAC)

| Rol | Descripción | Permisos Principales |
| :--- | :--- | :--- |
| **`ROLE_CLIENT`** | Usuario solicitante de servicios. | `orders:create`, `orders:cancel`, `reviews:create`, `payments:pay` |
| **`ROLE_PROFESSIONAL`** | Técnico o proveedor de servicios. | `orders:read`, `orders:accept`, `orders:complete`, `profile:update` |
| **`ROLE_ADMIN`** | Administrador de la plataforma. | `users:manage`, `disputes:resolve`, `system:audit` |
