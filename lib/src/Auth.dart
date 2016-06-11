part of gameKeyLib;

String getSignature(String id, String pwdOrSecret) {
  return BASE64.encode(sha256
      .convert(UTF8.encode(id + "," + pwdOrSecret))
      .bytes);
}

bool authenticate(Map entity, String pwdOrSecret) {
  if (entity != null && pwdOrSecret != null) {
    return entity['signature'] == getSignature(entity['id'], pwdOrSecret);
  }
  else {
    return false;
  }
}