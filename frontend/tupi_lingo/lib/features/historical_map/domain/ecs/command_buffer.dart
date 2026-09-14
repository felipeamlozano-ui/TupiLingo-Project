typedef CommandAction = void Function();

/// Thread-safe Command Buffer recording mutations to apply between system ticks (ADR-021).
class CommandBuffer {
  final List<CommandAction> _commands = [];

  void record(CommandAction action) {
    _commands.add(action);
  }

  void playback() {
    for (final cmd in _commands) {
      cmd();
    }
    _commands.clear();
  }
}
