# homecare_app

## Authentication API Overview

### `POST /auth/register`

- **Request Body**: `{ "name": string, "email": string, "password": string }`
- **Success Response**: Returns the created user along with freshly issued
  `accessToken` and `refreshToken`. The JSON payload has the shape:

  ```json
  {
    "message": "registration successful",
    "user": { "id": "...", "name": "...", "email": "..." },
    "accessToken": "<jwt>",
    "refreshToken": "<jwt>"
  }
  ```

  Clients should persist these tokens to establish an authenticated session.