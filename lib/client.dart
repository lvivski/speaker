library speaker_client;

import 'dart:html';
import 'dart:convert';
import 'dart:async';

class SpeakerClient {
  WebSocket _socket;
  List<int> _sockets;
  int _self;

  var _connections = new Map<int,RtcPeerConnection>();
  var _data = new Map<int,RtcDataChannel>();
  var _streams = new List<MediaStream>();

  var _messageController = new StreamController();
  Stream _messages;
  Stream _messageStream;

  var _iceServers = {
    'iceServers': [{
      'url': 'stun:stun.l.google.com:19302'
    }]
  };

  var _dataConfig = {
    'optional': [{
      'RtpDataChannels': true
    }, {
      'DtlsSrtpKeyAgreement': true
    }]
  };

  /* dart2js doesn't do recursive convertDartToNative_Dictionary()
   * and it fails in Chrome
   * so I had to remove constraints for now
  var _constraints = {
    'optional': [],
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true
    }
  };
  */

  var _constraints = {};

  SpeakerClient(url, { room: '' }): _socket = new WebSocket(url) {
    _messageStream = _messageController.stream.asBroadcastStream();

    _socket.onOpen.listen((e){
      _send('join', {
        'room': room
      });
    });

    _socket.onClose.listen((e){});

    _messages = _socket.onMessage.map((e) => JSON.decode(e.data));

    onPeers.listen((message) {
      _self = message['you'];
      _sockets = message['connections'];
    });

    onCandidate.listen((message) {
      var candidate = new RtcIceCandidate({
        'sdpMLineIndex': message['label'],
        'candidate': message['candidate']
      });

      _connections[message['id']].addIceCandidate(candidate);
    });

    onNew.listen((message) {
      var id = message['id'];
      var pc = _createPeerConnection(message['id']);

      _sockets.add(id);
      _connections[id] = pc;
      _streams.forEach((s) {
        pc.addStream(s);
      });
    });

    onLeave.listen((message) {
      var id = message['id'];
      _connections.remove(id);
      _data.remove(id);
      _sockets.remove(id);
    });

    onOffer.listen((message) {
      var pc = _connections[message['id']];
      pc.setRemoteDescription(new RtcSessionDescription(message['description']));
      _createAnswer(message['id'], pc);
    });

    onAnswer.listen((message) {
      var pc = _connections[message['id']];
      pc.setRemoteDescription(new RtcSessionDescription(message['description']));
    });
  }

  get onOffer => _messages.where((m) => m['type'] == 'offer');

  get onAnswer => _messages.where((m) => m['type'] == 'answer');

  get onCandidate => _messages.where((m) => m['type'] == 'candidate');

  get onNew => _messages.where((m) => m['type'] == 'new');

  get onPeers => _messages.where((m) => m['type'] == 'peers');

  get onLeave => _messages.where((m) => m['type'] == 'leave');

  get onAdd => _messageStream.where((m) => m['type'] == 'add');

  get onRemove => _messageStream.where((m) => m['type'] == 'remove');

  get onData => _messageStream.where((m) => m['type'] == 'data');

  createStream({ audio: false, video: false }) {
    var completer = new Completer<MediaStream>();

    window.navigator.getUserMedia(audio: audio, video: video).then((stream) {
      var video = new VideoElement()
        ..autoplay = true
        ..src = Url.createObjectUrl(stream);

      _streams.add(stream);

      _sockets.forEach((s) {
        _connections[s] = _createPeerConnection(s);
      });

      _streams.forEach((s) {
        _connections.forEach((k, c) => c.addStream(s));
      });

      _connections.forEach((s, c) => _createDataChannel(s, c));

      _connections.forEach((s, c) => _createOffer(s, c));

      completer.complete(stream);
    });

    return completer.future;
  }

  send(data) {
    _data.forEach((k, d) {
      d.send(data);
    });
  }

  _createPeerConnection(id) {
    var pc = new RtcPeerConnection(_iceServers, _dataConfig);

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
      _messageController.add({
        'type': 'add',
        'id': id,
        'stream': e.stream
      });
    });

    pc.onRemoveStream.listen((e) {
      _messageController.add({
        'type': 'remove',
        'id': id,
        'stream': e.stream
      });
    });

    pc.onDataChannel.listen((e) {
      _addDataChannel(id, e.channel);
    });

    return pc;
  }

  _addDataChannel(id, RtcDataChannel channel) {
    channel.onOpen.listen((e){});

    channel.onMessage.listen((e){
      _messageController.add({
        'type': 'data',
        'id': id,
        'data': e.data
      });
    });

    channel.onClose.listen((e){});

    _data[id] = channel;
  }

  _createDataChannel(id, RtcPeerConnection pc, { label: 'fileTransfer' }) {
    var channel = pc.createDataChannel(label, { 'reliable': false });
    _addDataChannel(id, channel);
  }

  _createOffer(int socket, RtcPeerConnection pc) {
    pc.createOffer(_constraints).then((RtcSessionDescription s) {
      pc.setLocalDescription(s);
      _send('offer', {
          'id': socket,
          'description': {
            'sdp': s.sdp,
            'type': s.type
          }
      });
    });
  }

  _createAnswer(int socket, RtcPeerConnection pc) {
    pc.createAnswer(_constraints).then((RtcSessionDescription s) {
      pc.setLocalDescription(s);
      _send('answer', {
          'id': socket,
          'description': {
            'sdp': s.sdp,
            'type': s.type
          }
      });
    });
  }

  _send(event, data) {
    data['type'] = event;
    _socket.send(JSON.encode(data));
  }
}
