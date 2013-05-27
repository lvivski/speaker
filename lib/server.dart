library speaker_server;

import 'dart:io';
import 'dart:async';
import 'dart:json' as JSON;

class SpeakerServer {
  HttpServer _server;

  var _sockets = new Map<int,WebSocket>();
  var _rooms = new Map<String,List<int>>();

  var _messageController = new StreamController();
  Stream _messages;

  SpeakerServer() {
    _messages = _messageController.stream.asBroadcastStream();

    onJoin.listen((message) {
      var socket = message['_socket'];

      if (_rooms[message['room']] == null) {
        _rooms[message['room']] = new List<int>();
      }

      _rooms[message['room']].forEach((client) {
        _sockets[client].add(JSON.stringify({
          'type': 'new',
          'id': socket.hashCode
        }));
      });

      socket.add(JSON.stringify({
        'type': 'peers',
        'connections': _rooms[message['room']],
        'you': socket.hashCode
      }));

      _rooms[message['room']].add(socket.hashCode);
    });

    onOffer.listen((message) {
      var socket = message['_socket'];

      var soc = _sockets[message['id']];

      soc.add(JSON.stringify({
        'type': 'offer',
        'description': message['description'],
        'id': socket.hashCode
      }));
    });

    onAnswer.listen((message) {
      var socket = message['_socket'];

      var soc = _sockets[message['id']];

      soc.add(JSON.stringify({
        'type': 'answer',
        'description': message['description'],
        'id': socket.hashCode
      }));
    });

    onCandidate.listen((message) {
      var socket = message['_socket'];

      var soc = _sockets[message['id']];

      soc.add(JSON.stringify({
        'type': 'candidate',
        'label': message['label'],
        'candidate': message['candidate'],
        'id': socket.hashCode
      }));
    });
  }

  get onJoin => _messages.where((m) => m['type'] == 'join');

  get onOffer => _messages.where((m) => m['type'] == 'offer');

  get onAnswer => _messages.where((m) => m['type'] == 'answer');

  get onCandidate => _messages.where((m) => m['type'] == 'candidate');

  Future<SpeakerServer> listen(String host, num port) {
    return HttpServer.bind(host, port).then((HttpServer server) {
      _server = server;

      _server.transform(new WebSocketTransformer()).listen((WebSocket socket) {
        _sockets[socket.hashCode] = socket;

        socket.listen((m) {
          var message = JSON.parse(m);
          message['_socket'] = socket;
          _messageController.add(message);
        },
        onDone: () {
          int id = socket.hashCode;
          _sockets.remove(id);

          _rooms.forEach((room, clients) {
            if (clients.contains(id)) {
              clients.remove(id);

              clients.forEach((client) {
                _sockets[client].add(JSON.stringify({
                  'type': 'leave',
                  'id': id
                }));
              });
            }
          });
        });
      });

      return this;
    });
  }
}