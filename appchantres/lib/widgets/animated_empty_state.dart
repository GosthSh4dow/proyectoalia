import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class AnimatedEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const AnimatedEmptyState({
    Key? key,
    required this.title,
    required this.message,
    required this.icon,
    this.color = Colors.grey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: color,
            ),
          )
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.5))
          .shake(hz: 4, curve: Curves.easeInOutCubic, duration: 1000.ms)
          .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1000.ms)
          .then(delay: 600.ms)
          .scale(begin: const Offset(1.1, 1.1), end: const Offset(1, 1), duration: 1000.ms),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }
}
