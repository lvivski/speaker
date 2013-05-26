import 'package:speak/server.dart';

void main() {
  new SpeakServer()..listen('127.0.0.1', 3001);
}