import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class PinDialog extends StatelessWidget {
  final String peerName;
  final String peerEmoji;
  final String pin;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  const PinDialog({
    super.key,
    required this.peerName,
    required this.peerEmoji,
    required this.pin,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF141828),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              blurRadius: 40,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(Icons.lock_rounded, color: Colors.white, size: 30),
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),

            Text('Verify Connection',
              style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '$peerEmoji $peerName wants to connect.\nMake sure both phones show the same PIN.',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // PIN display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E1A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF3ECFCF).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: pin.split('').map((digit) => Container(
                  width: 38, height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2435),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text(digit,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF3ECFCF),
                        fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                ).animate(delay: (pin.indexOf(digit) * 60).ms)
                    .scale(duration: 300.ms, curve: Curves.elasticOut)).toList(),
              ),
            ),
            const SizedBox(height: 10),
            Text('Ask your friend to verify their PIN matches',
              style: GoogleFonts.outfit(color: Colors.white24, fontSize: 11),
            ),
            const SizedBox(height: 28),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onReject,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Center(
                        child: Text('Reject',
                          style: GoogleFonts.outfit(
                              color: Colors.white54, fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onConfirm,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.4),
                          blurRadius: 12, offset: const Offset(0, 4),
                        )],
                      ),
                      child: Center(
                        child: Text('Confirm ✓',
                          style: GoogleFonts.outfit(
                              color: Colors.white, fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
