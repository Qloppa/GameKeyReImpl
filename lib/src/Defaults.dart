part of gameKeyLib;

const defaultHost = '0.0.0.0';
const defaultPort = 8080;
const defaultStoragePath = "gamekey.json";

final DB =
{
  'service': 'Gamekey',
  'storage': new Uuid().v4(), //TODO toString?
  'version': version,
  'users': [],
  'games': [],
  'gamestates': []
};

//var sha256 = new SHA256();

String testHost = "http://localhost:" + defaultPort;

bool isEmail(String email) {
  String VALID_EMAIL_REGEX = r'\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z';
  RegExp regExp = new RegExp(VALID_EMAIL_REGEX);
  return regExp.hasMatch(email);
}

bool isURL(String url) {
  String VALID_URL_REGEX = r'\A#{URI::regexp(["http", "https"])}\z';
  RegExp regExp = new RegExp(VALID_URL_REGEX);
  return regExp.hasMatch(url);
}

final testHash =
{
  'this' : 'is',
  'a' : ['simple', 'test']
};

List testList = ['This', 'is', 'a', 'Test'];