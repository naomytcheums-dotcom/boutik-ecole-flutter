/// Hors navigateur : pas de dictée vocale.
class Dictation {
  bool get supported => false;
  void start({required void Function(String text, bool isFinal) onText, required void Function() onEnd, required void Function(String error) onError}) => onError('unsupported');
  void stop() {}
}
