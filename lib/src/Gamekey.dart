part of gameKeyLib;

class GamekeyService {

  //URI's //TODO reguläre Ausdrücke anpassen
  final usersUrl = new UrlPattern(r'/users');
  final userUrl = new UrlPattern(r'/user/((\w+)(-\w+)*)');
  final userPostUrl = new UrlPattern(r'/user');
  final userGetUrl = new UrlPattern(r'/user/(.+)');

  final gamesUrl = new UrlPattern(r'/games');
  final gameUrl = new UrlPattern(r'/game/((\w+)(-\w+)*)');
  final gamePostUrl = new UrlPattern(r'/game');

  final gameStatesUrl = new UrlPattern(r'/gamestate/((\w+)(-\w+)*)');
  final gameStateUrl = new UrlPattern(
      r'/gamestate/((\w+)(-\w+)*)/((\w+)(-\w+)*)');

  /**
   * Used JSON pretty print encoder.
   */
  final json = new JsonEncoder.withIndent('  ');

  //TODO wofür ist der genau nötig?

  //init Variables
  File file = new File(defaultStoragePath);
  var storage = defaultStoragePath;
  int port = defaultPort;
  Map memory;

  GamekeyService({var storage: defaultStoragePath, int port: defaultPort}) {
    this.storage = storage;
    this.port = port;
    this.memory = readJsonFile();
  }

  newUuid() {
    var uuid = new Uuid();
    var id = uuid.v1().toString();
    return id;
  }

  Map readJsonFile() {
    Map ret;
    if (file.existsSync() == false) {
      file.writeAsStringSync(JSON.encode(DB));
    }
    ret = JSON.decode(file.readAsStringSync());
    return ret;
  }

  //TODO return als escape?!? der erste user soll returnt werden
  get_user_by_id(id) {
    var user;
    for (user in this.memory['users']) {
      if (user['id'] == id) {
        return user;
      }
    }
    return null;
  }

  get_user_by_name(name) {
    var user;
    for (user in this.memory['users']) {
      if (user['name'] == name) {
        return user;
      }
    }
    return null;
  }

  get_game_by_id(id) {
    var game;
    for (game in this.memory['games']) {
      if (game['id'] == id) {
        return game;
      }
    }
    return null;
  }

  void enableCors(HttpResponse response) {
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add('Access-Control-Allow-Methods',
        'HEAD, GET, PUT, POST, DELETE, OPTIONS');
    response.headers.add('Access-Control-Allow-Headers',
        'charset, pwd, secret, name, mail, newpwd');
  }

  Future<Router> serve({ip: '0.0.0.0', port: defaultPort}) async {
    final server = await HttpServer.bind(ip, port);

    final router = new Router(server)
      ..serve(userUrl, method: 'OPTIONS').listen(userOptions)
      ..serve(userPostUrl, method: 'OPTIONS').listen(userPostOptions)
      ..serve(userGetUrl, method: 'OPTIONS').listen(userGetOptions)
      ..serve(userPostUrl, method: 'POST').listen(postUser)
      ..serve(userGetUrl, method: 'GET').listen(getUser)
      ..serve(userUrl, method: 'PUT').listen(putUser)
      ..serve(userUrl, method: 'DELETE').listen(deleteUser)
      ..serve(usersUrl, method: 'GET').listen(getUsers)

      ..serve(gameUrl, method: 'OPTIONS').listen(gameOptions)
      ..serve(gamePostUrl, method: 'OPTIONS').listen(gamePostOptions)
      ..serve(gamePostUrl, method: 'POST').listen(postGame)
      ..serve(gameUrl, method: 'GET').listen(getGame)
      ..serve(gameUrl, method: 'PUT').listen(putGame)
      ..serve(gameUrl, method: 'DELETE').listen(deleteGame)
      ..serve(gamesUrl, method: 'GET').listen(getGames)

      ..serve(gameStateUrl, method: 'OPTIONS').listen(gameStateOptions)
      ..serve(gameStateUrl, method: 'POST').listen(postGameState)
    //Retrieves all gamestates stored for a game and a user.
      ..serve(gameStateUrl, method: 'GET').listen(getGameState)
    //Retrieves all gamestates stored for a game.
      ..serve(gameStatesUrl, method: 'GET').listen(getGameStates);
    return new Future.value(router);
  }

  userOptions(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.write('OPTIONS, POST, GET, PUT, DELETE');
    response.close();
  }

  userPostOptions(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.write('OPTIONS, POST');
    response.close();
  }

  userGetOptions(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.write('OPTIONS, GET');
    response.close();
  }

  postUser(HttpRequest request) {
    String name;
    String pwd;
    String mail;
    String id;
    String signature;
    Map user = new Map();
    HttpResponse response = request.response;
    enableCors(response);
    request.transform(UTF8.decoder).join("\n").then((body) {
      Map params = Uri
          .parse("?$body")
          .queryParameters;
      if (params.isEmpty == true) {
        params = request.uri.queryParameters;
      }

      name = params['name'];
      user = get_user_by_name('name');
      if (user != null) {
        response.statusCode = HttpStatus.CONFLICT;
        response.reasonPhrase = 'Already existing';
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      if (params.containsKey('name') == false) {
        response.statusCode = HttpStatus.BAD_REQUEST;
        response.reasonPhrase = "Bad Request: '${name}' is not a valid name";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      if (params.containsKey('pwd') == false) {
        response.statusCode = HttpStatus.BAD_REQUEST;
        response.reasonPhrase =
        "Bad Request: password must be provided and not be empty";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      if (params.containsKey('mail') == true) {
        mail = params['mail'];
      } else {
        mail = "";
      }

      pwd = params['pwd'];
      id = newUuid();
      signature = getSignature(id, pwd);

      user = {
        'type' : 'user',
        'name' : name,
        'id' : id,
        'created' : "${new DateTime.now().toUtc().toIso8601String()}",
        'mail' : mail,
        'signature' : signature,
      };
      memory['users'].add(user);

      response.statusCode = HttpStatus.OK;
      response.write(JSON.encode(user));
      response.close();
      file.writeAsStringSync(JSON.encode(memory));
    });
  }

  getUser(HttpRequest request) {
    String pwd;
    final userid = request.uri.pathSegments[1];
    String byname;
    Map user = new Map();
    Map userClone = new Map();
    List gameStateList = new List();

    HttpResponse response = request.response;
    enableCors(response);
    request.transform(UTF8.decoder).join("\n").then((body) {
      Map params = Uri.parse("?$body").queryParameters;
      if (params.isEmpty == true || params == {}) {
        params = request.uri.queryParameters;
      }
      byname = params['byname'];
      print(byname);
      pwd = params['pwd'];

      if (params.containsKey('byname')) {
        if ((byname == 'false') && (byname == 'true')) {
          response.statusCode = HttpStatus.BAD_REQUEST;
          response.reasonPhrase =
          "Bad Request: byname parameter must be 'true' or 'false' (if set), was '${byname}'.";
          response.write(response.reasonPhrase);
          response.close();
          return;
        }
      }
      if (byname == 'true') {
        user = get_user_by_name(userid);
        print(user);
      }
      if (byname == 'false') {
        user = get_user_by_id(userid);
        print(user);
      }
      if (user == null) {
        response.statusCode = HttpStatus.NOT_FOUND;
        response.reasonPhrase = "Not Found";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }
      if (authenticate(user, pwd) == false) {
        response.statusCode = HttpStatus.UNAUTHORIZED;
        response.reasonPhrase =
        "unauthorized, please provide correct credentials";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }
      for (Map gameState in memory['gamestates']) {
        if (gameState['userid'] == userid &&
            gameStateList.contains(gameState['gameid']) == false) {
          gameStateList.add(gameState['gameid']);
        }
      }
      userClone.addAll(user);
      userClone['games'] = gameStateList;

      response.statusCode = HttpStatus.OK;
      response.write(JSON.encode(userClone));
      response.close();
    });
  }

  putUser(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.close();
  }

  deleteUser(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.close();
  }

  getUsers(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.headers.contentType =
    new ContentType('application', 'json', charset: 'UTF-8');
    response.write(json.convert(memory['users']));
    response.close();
  }

  gameOptions(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.write('OPTIONS, POST, GET, PUT, DELETE');
    response.close();
  }

  gamePostOptions(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.write('OPTIONS, POST');
    response.close();
  }

  postGame(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.close();
  }

  getGame(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.close();
  }

  putGame(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.close();
  }

  deleteGame(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.close();
  }

  getGames(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.headers.contentType =
    new ContentType('application', 'json', charset: 'UTF-8');
    response.write(json.convert(memory['games']));
    response.close();
  }

  gameStateOptions(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.write('OPTIONS, POST, GET');
    response.close();
  }

  postGameState(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.close();
  }

  getGameState(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.close();
  }

  getGameStates(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.headers.contentType =
    new ContentType('application', 'json', charset: 'UTF-8');
    response.write(json.convert(memory['gamestates']));
    response.close();
  }

  api() {
    //möglicherweise auch main()

  }
}