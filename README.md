# Speaker
WebRTC client/server library

## Usage

### Server

```dart
import 'package:speaker/server.dart';

void main() {
  new SpeakerServer()..listen('127.0.0.1', 3001);
}
```

### Client

#### API

You start your stream with `.createStream()` method. 

There are several Event Streams for you 

* `onAdd` - when a peer is connected
* `onLeave` - when peer leaves
* `onData` - receive p2p data

You can send p2p data via `.send()` method (data will be sent to all peers).

#### Example

```dart
import 'dart:html';
import 'package:speaker/client.dart';

void main() {
  var speaker = new SpeakerClient('ws://127.0.0.1:3001', room: 'room');

  speaker.createStream(video: true).then((stream) {
    var video = new VideoElement()
      ..autoplay = true
      ..src = Url.createObjectUrl(stream);

    document.body.append(video);
  });

  speaker.onAdd.listen((message) {
    var video = new VideoElement()
      ..id = 'remote${message['id']}'
      ..autoplay = true
      ..src = Url.createObjectUrl(message['stream']);

    document.body.append(video);
  });

  speaker.onLeave.listen((message) {
    document.query('#remote${message['id']}').remove();
  });
}
```