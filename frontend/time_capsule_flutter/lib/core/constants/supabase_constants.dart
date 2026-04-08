class SupabaseConstants {
  static const String url = 'https://jfomtwnzhalvmkhoxqgo.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impmb210d256aGFsdm1raG94cWdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0MDUyNTMsImV4cCI6MjA4OTk4MTI1M30.9gUvKpH4-89bjgzxeavlwVKpPpVUpwpZUI-WjI1X8OE';

  /// Returns a deterministic channel name for a 1-on-1 chat.
  static String chatChannel(String myId, String otherId) {
    final ids = [myId, otherId]..sort();
    return 'chat:${ids[0]}:${ids[1]}';
  }
}
