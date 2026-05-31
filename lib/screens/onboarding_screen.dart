import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/nearby_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final NearbyService nearbyService;
  const OnboardingScreen({super.key, required this.nearbyService});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '😊';
  bool _isLoading = false;

  final List<String> _emojis = [
  // Animals
  '🦁','🐯','🐻','🦊','🐺','🐗','🦝','🦨','🦦','🦥','🐼','🐨',
  // Birds
  '🦅','🦆','🦉','🦚','🦜','🐦','🕊️','🦩','🦢','🐧','🦤','🪶',
  // Insects
  '🦋','🐝','🪲','🐛','🦗','🪳','🐞','🦟','🪰','🦂','🐜','🪱',
  // Flowers
  '🌸','🌺','🌻','🌹','🌷','💐','🪷','🌼','🌸','🏵️','🪻','🌱',
];
  Future<void> _continue() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name',  _nameController.text.trim());
    await prefs.setString('user_emoji', _selectedEmoji);
    await widget.nearbyService.initialize(_nameController.text.trim(), _selectedEmoji);
    if (mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => HomeScreen(nearbyService: widget.nearbyService)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.45),
                        blurRadius: 32, spreadRadius: 4)],
                  ),
                  child: const Center(child: Text('💬', style: TextStyle(fontSize: 44))),
                ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              ),
              const SizedBox(height: 28),
              Center(child: Text('Linko',
                style: GoogleFonts.outfit(fontSize: 44, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -1.5),
              ).animate().fadeIn(delay: 200.ms)),
              Center(child: Text('Connect. Chat. No internet needed.',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white38),
              ).animate().fadeIn(delay: 350.ms)),
              const SizedBox(height: 48),

              // Avatar picker
              Text('Pick your avatar',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ).animate().fadeIn(delay: 450.ms),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemCount: _emojis.length,
                itemBuilder: (context, i) {
                  final emoji   = _emojis[i];
                  final selected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedEmoji = emoji);
                    },
                    child: AnimatedContainer(
                      duration: 180.ms,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF6C63FF).withOpacity(0.25)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? const Color(0xFF6C63FF) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                    ),
                  );
                },
              ).animate().fadeIn(delay: 550.ms),
              const SizedBox(height: 28),

              // Name input
              Text('Your name',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ).animate().fadeIn(delay: 650.ms),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'e.g. Khush',
                  hintStyle: GoogleFonts.outfit(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2)),
                  prefixIcon: Padding(padding: const EdgeInsets.all(14),
                      child: Text(_selectedEmoji, style: const TextStyle(fontSize: 22))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _continue(),
              ).animate().fadeIn(delay: 720.ms),
              const SizedBox(height: 36),

              // CTA
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _isLoading ? null : _continue,
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.45),
                          blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text('Get Started',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 850.ms).slideY(begin: 0.3, end: 0),
              const SizedBox(height: 20),
              Center(child: Text('Encrypted · Offline · Peer-to-peer',
                style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12),
              ).animate().fadeIn(delay: 950.ms)),
            ],
          ),
        ),
      ),
    );
  }
}
