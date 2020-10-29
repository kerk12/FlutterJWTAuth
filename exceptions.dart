
enum AuthError {
  Unauthorized,
  APIError
}

class AuthenticationException implements Exception {
  AuthError cause;

  AuthenticationException(this.cause);
}