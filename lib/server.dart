library speak_server;

import 'dart:io';
import 'dart:async';
import 'dart:json' as JSON;
import 'dart:collection';

class SpeakServer {
  HttpServer _server;
  var _sockets = new Map<int,WebSocket>();
  var _handlers = new List<Map>();
  var _rooms = new Map<String,List<int>>();

  SpeakServer() {
    on('join', (event, socket) {
      if (_rooms[event['room']] == null) {
        _rooms[event['room']] = new List<int>();
      }

      _rooms[event['room']].forEach((client) {
        _sockets[client].add(JSON.stringify({
          'type': 'new',
          'id': socket.hashCode
        }));
      });

      socket.add(JSON.stringify({
        'type': 'peers',
        'connections': _rooms[event['room']],
        'you': socket.hashCode
      }));

      _rooms[event['room']].add(socket.hashCode);
    });

    on('offer', (event, socket) {
      var soc = _sockets[event['id']];

      soc.add(JSON.stringify({
        'type': 'offer',
        'sdp': event['sdp'],
        'id': socket.hashCode
      }));
    });

    on('answer', (event, socket) {
      var soc = _sockets[event['id']];

      soc.add(JSON.stringify({
        'type': 'answer',
        'sdp': event['sdp'],
        'id': socket.hashCode
      }));
    });

    on('candidate', (event, socket) {
      var soc = _sockets[event['id']];

      soc.add(JSON.stringify({
        'type': 'candidate',
        'label': event['label'],
        'candidate': event['candidate'],
        'id': socket.hashCode
      }));
    });
  }

  Future<SpeakServer> listen(String host, num port) {
    return HttpServer.bind(host, port).then((HttpServer server) {
      _server = server;

      _server.transform(new WebSocketTransformer()).listen((WebSocket socket) {
        _sockets[socket.hashCode] = socket;

        socket.listen((event) {
          emit(event, socket);
        },
        onDone: () {
          int id = socket.hashCode;
          _sockets.remove(id);

          Maps.forEach(_rooms, (room, clients) {
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

  emit(event, socket) {
    event = JSON.parse(event);
    var handlers = _lookup(event);
    if (handlers.length > 0) {
      handlers.forEach((handler) => handler['handler'](event, socket));
    }
  }

  on(event, handler) {
    _handlers.add({
      'event': event,
      'handler': handler
    });
  }

  List<Map> _lookup(Map event) => _handlers.where((handler) => handler['event'] == event['type']).toList();
}