library speak_client;

import 'dart:html';
import 'dart:json' as JSON;

class SpeakClient {
  var _handlers = new List<Map>();
  WebSocket _socket;
  List<int> _sockets;
  int _self;
  var _connections = new Map<int,RtcPeerConnection>();
  var _streams = new List<MediaStream>();

  var iceServers = {
    'iceServers': [{
      'url': 'stun:stun.l.google.com:19302'
    }]
  };

  SpeakClient(url) {
    _socket = new WebSocket(url);

    _socket.onOpen.listen((e){
      _send('join', {
        'room': ''
      });
    });

    _socket.onMessage.listen((e){
      var event = JSON.parse(e.data);
      emit(event);
    });

    _socket.onClose.listen((e){});

    on('peers', (event) {
      _self = event['you'];
      _sockets = event['connections'];
    });

    on('candidate', (event) {
      var candidate = new RtcIceCandidate({
        'sdpMLineIndex': event['label'],
        'candidate': event['candidate']
      });

      _connections[event['id']].addIceCandidate(candidate);
    });

    on('new', (event) {
      var id = event['id'];

      var pc = createPeerConnection(event['id']);

      _sockets.add(id);

      _connections[id] = pc;

      _streams.forEach((s) {
        pc.addStream(s);
      });
    });

    on('offer', (event) {
      var pc = _connections[event['id']];

      pc.setRemoteDescription(new RtcSessionDescription(event['sdp']));
      createAnswer(event['id'], pc);
    });

    on('answer', (event) {
      var pc = _connections[event['id']];

      pc.setRemoteDescription(new RtcSessionDescription(event['sdp']));
    });
  }

  createPeerConnection(id) {
    var pc = new RtcPeerConnection(iceServers);

    pc.onIceCandidate.listen((e){
      if (e.candidate != null) {
        _send('candidate', {
          'label': e.candidate.sdpMLineIndex,
          'id': id,
          'candidate': e.candidate.candidate
        });
      }
    });

    pc.onAddStream.listen((e) {
      emit({
        'type': 'add',
        'data': e
      });
    });

    pc.onRemoveStream.listen((e) {
      emit({
        'type': 'remove',
        'data': e
      });
    });

    return pc;
  }

  createStream(callback) {
    window.navigator.getUserMedia(audio: false, video: true).then((stream) {
      var video = new VideoElement()
        ..autoplay = true
        ..src = Url.createObjectUrl(stream);

      _streams.add(stream);


      _sockets.forEach((s) {
        _connections[s] = createPeerConnection(s);
      });

      _streams.forEach((s) {
        _connections.forEach((k, c) => c.addStream(s));
      });

      _connections.forEach((s, c) => createOffer(s, c));

      callback(stream);
    });
  }

  createOffer(int socket, RtcPeerConnection pc) {
    var constraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true
      }
    };

    pc.createOffer(constraints).then((RtcSessionDescription s) {
      pc.setLocalDescription(s);
      _send('offer', {
          'id': socket,
          'sdp': {
            'sdp': s.sdp,
            'type': s.type
          }
      });
    });
  }

  createAnswer(int socket, RtcPeerConnection pc) {
    var constraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true
      }
    };

    pc.createAnswer(constraints).then((RtcSessionDescription s) {
      pc.setLocalDescription(s);
      _send('answer', {
          'id': socket,
          'sdp': {
            'sdp': s.sdp,
            'type': s.type
          }
      });
    });
  }

  _send(event, data) {
    data['type'] = event;
    _socket.send(JSON.stringify(data));
  }

  emit(event) {
    var handlers = _lookup(event);
    if (handlers.length > 0) {
      handlers.forEach((handler) => handler['handler'](event));
    }
  }

  on(event, handler) {
    _handlers.add({
      'event': event,
      'handler': handler
    });
  }

  List<Map> _lookup(Map event) =>
      _handlers.where((handler) => handler['event'] == event['type']).toList();
}