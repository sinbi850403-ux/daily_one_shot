/// Tracks whether biometric lock is enabled and whether the current session
/// has been unlocked. Persisted via a tiny SharedPreferences-free approach:
/// the value lives in the AppDatabase via a settings table — but to keep the
/// data layer simple for MVP, we use an in-memory + file-backed flag.
class BiometricLock {
  BiometricLock._();
  static final BiometricLock instance = BiometricLock._();

  bool _enabled = false;
  bool _unlockedThisSession = false;

  bool get enabled => _enabled;
  bool get unlockedThisSession => _unlockedThisSession;

  /// Call on app boot once SharedPreferences/SettingsRepo is wired.
  /// MVP keeps it in memory; full persistence is post-MVP.
  Future<void> load() async {
    // TODO: persist via settings table; in MVP defaults to off.
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    if (!v) _unlockedThisSession = false;
  }

  void markUnlocked() {
    _unlockedThisSession = true;
  }

  void lock() {
    _unlockedThisSession = false;
  }
}
