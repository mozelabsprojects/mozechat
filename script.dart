import 'dart:io';

void main() {
  final file = File('lib/widgets/message_bubble.dart');
  var code = file.readAsStringSync();
  
  // 1. remove import dart:async from class
  code = code.replaceAll('  import \'dart:async\';\n', '');
  
  // 2. add import dart:async at top
  if (!code.contains('import \'dart:async\';')) {
    code = 'import \'dart:async\';\n$code';
  }
  
  // 3. Fix oldWidget.widget.msg to oldWidget.msg
  code = code.replaceAll('oldWidget.widget.msg', 'oldWidget.msg');
  
  // 4. Fix named arguments
  code = code.replaceAll('widget.textColor:', 'textColor:');
  code = code.replaceAll('widget.isMe:', 'isMe:');
  code = code.replaceAll('widget.isBot:', 'isBot:');
  code = code.replaceAll('widget.currentBg:', 'currentBg:');
  code = code.replaceAll('widget.borderColor:', 'borderColor:');
  code = code.replaceAll('widget.msg:', 'msg:');
  code = code.replaceAll('widget.replyText:', 'replyText:');
  
  // 5. Check if there's any stray Timer issues? No, dart:async covers it.
  
  file.writeAsStringSync(code);
}
