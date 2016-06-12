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
        'GET, PUT, POST, DELETE, OPTIONS');
    response.headers.add('Access-Control-Allow-Headers',
        'Origin, X-Requested-With, Content-Type, Accept, Charset');
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
      ..serve(gameStateUrl, method: 'GET').listen(getGameStateGid)
    //Retrieves all gamestates stored for a game.
      ..serve(gameStatesUrl, method: 'GET').listen(getGameStateGidUid);
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
      pwd = params['pwd'];
      if (name == null) {
        response.statusCode = HttpStatus.BAD_REQUEST;
        response.reasonPhrase = "Bad Request: '${name}' is not a valid name";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      if (pwd == null) {
        response.statusCode = HttpStatus.BAD_REQUEST;
        response.reasonPhrase =
        "Bad Request: password must be provided and not be empty";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      //TODO EMAIL geschichte inklusive badRequest und EMAIL_REGEX


      user = get_user_by_name(name);
      if (user != null) {
        response.statusCode = HttpStatus.CONFLICT;
        response.reasonPhrase = "User with name '${name}' exists already.";
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
    final id = request.uri.pathSegments[1];
    String byname;
    Map user = new Map();
    Map userClone = new Map();
    List gameStateList = new List();

    HttpResponse response = request.response;
    enableCors(response);
    request.transform(UTF8.decoder).join("\n").then((body) {
      Map params = Uri
          .parse("?$body")
          .queryParameters;
      if (params.isEmpty) {
        params = request.uri.queryParameters;
      }

      byname = params['byname'];
      pwd = params['pwd'];

      if (params.containsKey('byname') == true) {
        if ((byname != 'false') && (byname != 'true')) {
          response.statusCode = HttpStatus.BAD_REQUEST;
          response.reasonPhrase =
          "Bad Request: byname parameter must be 'true' or 'false' (if set), was '${byname}'.";
          response.write(response.reasonPhrase);
          response.close();
          return;
        }
      }

      if (byname == 'true') {
        user = get_user_by_name(
            id); //TODO müsste hier nicht der Name übergeben werden
      } else {
        user = get_user_by_id(id);
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
        if (gameState['userid'] == id &&
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
    final id = userUrl
        .parse(request.uri.path)
        .first;
    String pwd;
    String new_name;
    String new_mail;
    String new_pwd;
    Map user = new Map();
    HttpResponse response = request.response;
    enableCors(response);
    request.transform(UTF8.decoder).join("\n").then((body) {
      Map params = Uri
          .parse("?$body")
          .queryParameters;
      if (params.isEmpty) {
        params = request.uri.queryParameters;
      }

      pwd = params['pwd'];
      new_name = params['name'];
      new_mail = params['mail'];
      new_pwd = params['newpwd'];
      user = get_user_by_id(id);

      if (user == null) {
        response.statusCode = HttpStatus.NOT_FOUND;
        response.reasonPhrase = "Not Found";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      if (get_user_by_name(new_name) != null) {
        response.statusCode = HttpStatus.CONFLICT;
        response.reasonPhrase = "User with name '${new_name}' exists already.";
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

      if (new_name != null) {
        user['name'] = new_name;
      }

      if (new_mail != null) {
        user['mail'] = new_mail;
      }

      if (new_pwd != null) {
        user['signature'] = getSignature(id, new_pwd);
      }
      user['update'] = "${new DateTime.now().toUtc().toIso8601String()}";

      //TODO wird der geänderte user überhaupt in die json geschrieben?
      //memory['users'].add(user); //TODO mit memory passiert doch garnichts!
      response.statusCode = HttpStatus.OK;
      response.write(JSON.encode(user));
      response.close();
      file.writeAsStringSync(JSON.encode(memory));
    });
  }

  deleteUser(HttpRequest request) {
    final id = userUrl
        .parse(request.uri.path)
        .first;
    String pwd;
    Map user = new Map();
    List deleteList = new List();
    HttpResponse response = request.response;
    enableCors(response);
    request.transform(UTF8.decoder).join("\n").then((body) {
      Map params = Uri
          .parse("?$body")
          .queryParameters;
      if (params.isEmpty) {
        params = request.uri.queryParameters;
      }
      pwd = params['pwd'];
      user = get_user_by_id(id);

      if (user == null) {
        response.statusCode = HttpStatus.OK;
        response.reasonPhrase = "User '${id}' deleted successfully.";
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

      memory['users'].remove(user); //TODO eventuell näher an kratzke

      //TODO zwei For Schleifen?
      for (Map gameState in memory['gamestates']) {
        if (gameState['userid'] == id) {
          deleteList.add(gameState);
        }
      }
      for (Map gamestate in deleteList) {
        memory['gamestates'].remove(gamestate);
      }

      response.statusCode = HttpStatus.OK;
      response.reasonPhrase = "User '${id}' deleted successfully.";
      response.write(response.reasonPhrase);
      response.close();
      file.writeAsStringSync(JSON.encode(memory));
    });
  }

  getUsers(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.headers.contentType =
    new ContentType('application', 'json', charset: 'UTF-8');
    response.write(JSON.encode(memory['users']));
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

  getGames(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.headers.contentType =
    new ContentType('application', 'json', charset: 'UTF-8');
    response.write(JSON.encode(memory['games']));
    response.close();
  }

  postGame(HttpRequest request) {
    String id = newUuid();
    String name;
    String secret;
    String url;
    String signature;
    Map game = new Map();
    HttpResponse response = request.response;
    enableCors(response);
    request.transform(UTF8.decoder).join("\n").then((body) {
      Map params = Uri
          .parse("?$body")
          .queryParameters;
      if (params.isEmpty) {
        params = request.uri.queryParameters;
      }
      name = params['name'];
      secret = params['secret'];

      if (params.containsKey('url') == true) {
        url = params['url'];
      } else {
        url = "";
      }

      if (name == null || name.isEmpty) {
        response.statusCode = HttpStatus.BAD_REQUEST;
        response.reasonPhrase =
        "Bad Request: '${name}' is not a valid name";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }
      if (secret == null || secret.isEmpty) {
        response.statusCode = HttpStatus.BAD_REQUEST;
        response.reasonPhrase =
        "Bad Request: 'secret must be provided";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      //TODO Uri nicht implementiert...
      /*
      if (uri != null && url.isEmpty == false) {
        if (uri.isAbsolute == false) {
          response.statusCode = HttpStatus.BAD_REQUEST;
          response.reasonPhrase =
          "Bad Request: '${url}' is not a valid absolute url";
          response.write(response.reasonPhrase);
          response.close();
          return;
        }
      }
      */

      for (Map game in memory['games']) {
        if (game['name'] == name) {
          response.statusCode = HttpStatus.CONFLICT;
          response.reasonPhrase = "Game with name '${name}' exists already.";
          response.write(response.reasonPhrase);
          response.close();
          return;
        }
      }
      //TODO URL müsste eigentlich noch auf REGEX geprüft werden
      signature = getSignature(id, secret);

      game = {
        'type':'game',
        'name': name,
        'id': id,
        'url': url,
        'signature': signature,
        'created': "${new DateTime.now().toUtc().toIso8601String()}",
      };

      memory['games'].add(game);

      response.statusCode = HttpStatus.OK;
      response.write(JSON.encode(game));
      response.close();
      file.writeAsStringSync(JSON.encode(memory));
    });
  }

  getGame(HttpRequest request) {
    String secret;
    final id = request.uri.pathSegments[1];
    Map game = new Map();
    Map gameClone = new Map();
    List gameStateList = new List();
    HttpResponse response = request.response;
    enableCors(response);
    request.transform(UTF8.decoder).join("\n").then((body) {
      Map params = Uri
          .parse("?$body")
          .queryParameters;
      if (params.isEmpty) {
        params = request.uri.queryParameters;
      }
      secret = params['secret'];
      game = get_game_by_id(id);

      if (game == null) {
        response.statusCode = HttpStatus.NOT_FOUND;
        response.reasonPhrase = "Not Found";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      if (authenticate(game, secret) == false) {
        response.statusCode = HttpStatus.UNAUTHORIZED;
        response.reasonPhrase =
        "unauthorized, please provide correct credentials";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      for (Map gameState in memory['gamestates']) {
        if (gameState["gameid"] == id &&
            gameStateList.contains(gameState["userid"]) == false) {
          gameStateList.add(gameState["userid"]);
        }
      }

      gameClone.addAll(game);
      gameClone['users'] = gameStateList;

      response.statusCode = HttpStatus.OK;
      response.write(JSON.encode(gameClone));
      response.close();
    });
  }

  putGame(HttpRequest request) {
    final id = gameUrl
        .parse(request.uri.path)
        .first;
    String secret;
    String new_name;
    String new_url;
    String new_secret;
    Map game = new Map();
    HttpResponse response = request.response;
    enableCors(response);
    request.transform(UTF8.decoder).join("\n").then((body) {
      Map params = Uri
          .parse("?$body")
          .queryParameters;
      if (params.isEmpty) {
        params = request.uri.queryParameters;
      }

      secret = params['secret'];
      new_name = params['name'];
      new_url = params['url'];
      new_secret = params['newsecret'];
      game = get_game_by_id(id);

      if (game == null) {
        response.statusCode = HttpStatus.NOT_FOUND;
        response.reasonPhrase = "Not Found";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      for (Map game in memory['games']) {
        if (game['name'] == new_name) {
          response.statusCode = HttpStatus.CONFLICT;
          response.reasonPhrase =
          "Game with name '${new_name}' exists already.";
          response.write(response.reasonPhrase);
          response.close();
          return;
        }
      }

      if (authenticate(game, secret) == false) {
        response.statusCode = HttpStatus.UNAUTHORIZED;
        response.reasonPhrase =
        "unauthorized, please provide correct credentials";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      if (new_name != null) {
        game['name'] = new_name;
      }
      if (new_url != null) {
        game['url'] = new_url;
      }
      if (new_secret != null) {
        game['secret'] = new_secret;
        game['signature'] = getSignature(id, new_secret);
      }
      game['update'] = "${new DateTime.now().toUtc().toIso8601String()}";

      response.statusCode = HttpStatus.OK;
      response.write(JSON.encode(game));
      response.close();
      file.writeAsStringSync(JSON.encode(memory));
    });
  }

  deleteGame(HttpRequest request) {
    final id = gameUrl
        .parse(request.uri.path)
        .first;
    String secret;
    Map game = new Map();
    List deleteList = new List();
    HttpResponse response = request.response;
    enableCors(response);
    request.transform(UTF8.decoder).join("\n").then((body) {
      Map params = Uri
          .parse("?$body")
          .queryParameters;
      if (params.isEmpty) {
        params = request.uri.queryParameters;
      }
      secret = params['secret'];
      game = get_game_by_id(id);

      if (game == null) {
        response.statusCode = HttpStatus.OK;
        response.reasonPhrase = "Game '${id}' deleted successfully.";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      if (authenticate(game, secret) == false) {
        response.statusCode = HttpStatus.UNAUTHORIZED;
        response.reasonPhrase =
        "unauthorized, please provide correct credentials";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      memory['games'].remove(game); //TODO eventuell näher an kratzke

      //TODO zwei For Schleifen?
      for (Map gameState in memory['gamestates']) {
        if (gameState['gameid'] == id) {
          deleteList.add(gameState);
        }
      }
      for (Map gamestate in deleteList) {
        memory['gamestates'].remove(gamestate);
      }

      response.statusCode = HttpStatus.OK;
      response.reasonPhrase = "Game '${id}' deleted successfully.";
      response.write(response.reasonPhrase);
      response.close();
      file.writeAsStringSync(JSON.encode(memory));
    });
  }

  getGameStateGidUid(HttpRequest request) {
    final pathsegments = request.uri.pathSegments;
    final gameid = pathsegments[1];
    final userid = pathsegments[2];
    String secret;
    Map game = new Map();
    Map user = new Map();
    Map gameStateClone = new Map();
    List userGameState = new List();
    HttpResponse response = request.response;
    enableCors(response);
    request.transform(UTF8.decoder).join("\n").then((body) {
      Map params = Uri
          .parse("?$body")
          .queryParameters;
      if (params.isEmpty) {
        params = request.uri.queryParameters;
      }
      secret = params['secret'];
      game = get_game_by_id(gameid);
      user = get_user_by_id(userid);

      if (game == null && user == null) {
        response.statusCode = HttpStatus.NOT_FOUND;
        response.reasonPhrase = "game id or user id not found";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      if (authenticate(game, secret) == false) {
        response.statusCode = HttpStatus.UNAUTHORIZED;
        response.reasonPhrase =
        "unauthorized, please provide correct game credentials";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      for(Map gameState in memory['gamestates']) {
        if ((gameState['gameid'] == gameid) && (gameState['userid'] == userid)) {
          gameStateClone.addAll(gameState);
          gameStateClone['gamename'] = game['name'];
          gameStateClone['username'] = user['name'];
          userGameState.add(gameStateClone);
        }
      }
      userGameState.sort((a, b) => b['created'].compareTo(a['created']));

      response.statusCode = HttpStatus.OK;
      response.write(JSON.encode(userGameState));
      response.close();
    });
  }

  getGameStateGid(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.close();
  }

  gameStateOptions(HttpRequest request) {
    HttpResponse response = request.response;
    enableCors(response);
    response.write('OPTIONS, POST, GET');
    response.close();
  }

  postGameState(HttpRequest request) {
    final pathsegments = request.uri.pathSegments;
    final gameid = pathsegments[1];
    final userid = pathsegments[2];
    //String gameid;
    //String userid;
    String secret;
    var state;
    Map game = new Map();
    Map user = new Map();
    Map statePost = new Map();
    HttpResponse response = request.response;
    enableCors(response);
    request.transform(UTF8.decoder).join("\n").then((body) {
      Map params = Uri
          .parse("?$body")
          .queryParameters;
      if (params.isEmpty) {
        params = request.uri.queryParameters;
      }
      //gameid = params['gameid'];
      //userid = params['userid'];
      secret = params['secret'];
      state = params['state'];
      game = get_game_by_id(gameid);
      user = get_user_by_id(userid);

      if (game == null && user == null) {
        response.statusCode = HttpStatus.NOT_FOUND;
        response.reasonPhrase = "game id or user id not found";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      if (authenticate(game, secret) == false) {
        response.statusCode = HttpStatus.UNAUTHORIZED;
        response.reasonPhrase =
        "unauthorized, please provide correct game credentials";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      state = JSON.decode(state); //TODO state als map testen
      if (state == null) {
        response.statusCode = HttpStatus.BAD_REQUEST;
        response.reasonPhrase =
        "Bad request: state must not be empty, was ${state}";
        response.write(response.reasonPhrase);
        response.close();
        return;
      }

      statePost = {
        'type' : 'gamestate',
        'gameid' : gameid,
        'userid' : userid,
        'created' : "${new DateTime.now().toUtc().toIso8601String()}",
        'state' : state,
      };

      memory['gamestates'].add(statePost);

      response.statusCode = HttpStatus.OK;
      response.write(JSON.encode(statePost));
      response.close();
      file.writeAsStringSync(JSON.encode(memory));
    });
  }

  api() {
    //möglicherweise auch main()

  }
}