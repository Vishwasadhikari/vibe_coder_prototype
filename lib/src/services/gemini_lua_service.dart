class GeminiLuaService {
  bool get isConfigured => false;

  Future<String> generateRobloxLua({required String prompt}) async {
    throw UnsupportedError('Gemini integration removed. Use Groq instead.');
  }
}
