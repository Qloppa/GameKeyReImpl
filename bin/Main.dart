import '../lib/GameKeyLib.dart';
import 'dart:io';
final test = true;

main() async{
  File f = new File(defaultStoragePath);
  if(test && f.existsSync())
  {
    f.deleteSync();
  }
  final server = new GamekeyService();
  server.serve();
}