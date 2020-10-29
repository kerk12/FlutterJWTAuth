/// Class responsible for handling authentication using JSON Web Token (JWT).
/// In this case, I'm using the `simplejwt` package in Django to provide JWT.
///
/// ## How to use:
/// 1. (If there are no stored credentials) use `tryLogin` to grab the JWT access
/// and refresh tokens:
/// ```dart
/// var as = AuthenticationService.tryLogin(username: "some_username", password: "some_password");
/// ```
/// 2. If you have stored the tokens and wish to reuse them, use the [fromCredentials] constructor.
/// ```dart
/// var as = AuthenticationService.fromCredentials(username: ..., access: ..., refresh: ...);
/// ```
/// 3. Once Authentication is complete, you can get the inner Dio client to handle all authenticated requests:
/// ```dart
/// var client = as.getAuthenticatedClient();
/// ```
/// 4. Then it's Dio business as usual:
/// ```dart
/// var response = client.get("/some/endpoint/requiring/auth/");
/// ```
///
/// **Warning:** This class doesn't include access token refresh capability (yet).
class AuthenticationService {
  // Static stuff
  // In case you haven't noticed, this is a singleton! :D
  static AuthenticationService _authService;
  static const String SHARED_PREFS_USERNAME = "auth_username";
  static const String SHARED_PREFS_ACCESS = "auth_access";
  static const String SHARED_PREFS_REFRESH = "auth_refresh";

  /// Returns the [AuthenticationService] instance or null if there's no auth done.
  static AuthenticationService getInstance() {
    return _authService;
  }

  static bool isAuthenticated() {
    return _authService != null;
  }

  /// Clears the credentials off of AuthenticationService.
  static void clear() {
    _authService = null;
  }

  /// Tries to login using the given [username] and [password].
  /// Should the login fail for any way, an [AuthenticationException] is raised.
  static Future<AuthenticationService> tryLogin({@required String username, @required String password}) async {
    final String url = "${Vars.API_ADDRESS}${Vars.AUTH_ENDPOINT}";

    var authResponse;
    try {
      authResponse = await Dio().post(
          url,
          data: <String, String>{
            "username": username,
            "password": password,
          }
      );
    } on DioError catch (e){
      if (e.error == "Http status error [401]")
        throw AuthenticationException(AuthError.Unauthorized);
      throw AuthenticationException(AuthError.APIError);
    }

    // Grab both the access and refresh token.
    final access = authResponse.data["access"];
    final refresh = authResponse.data["refresh"];

    // Store the token to SP.
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.setString(SHARED_PREFS_USERNAME, username);
    sp.setString(SHARED_PREFS_ACCESS, access);
    sp.setString(SHARED_PREFS_REFRESH, refresh);

    // Create a new instance of AuthenticationService.
    return AuthenticationService.fromCredentials(username: username, access: access, refresh: refresh);
  }

  // Credentials
  String username;
  String access;
  String refresh;
  final Dio _authClient;

  /// Default private constructor.
  /// Creates a [Dio] instance with the access token integrated for authentication.
  AuthenticationService._({@required this.username, @required this.access, @required this.refresh}) :
    _authClient = Dio(BaseOptions(
      baseUrl: Vars.API_ADDRESS,
      headers: { "Authorization": "Bearer ${access}" }
    ));

  /// Creates an [AuthenticationService] instance using the given auth tokens and username.
  factory AuthenticationService.fromCredentials({@required username, @required access, @required refresh}) {
    _authService = AuthenticationService._(username: username, access: access, refresh: refresh);
    return _authService;
  }

  /// Gets the [Dio] instance with builtin authentication.
  Dio getAuthenticatedClient() => this._authClient;

}