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