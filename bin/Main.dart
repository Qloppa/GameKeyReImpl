import '../lib/GameKeyLib.dart';

main() async{
  final server = new GamekeyService();
  server.serve();
}