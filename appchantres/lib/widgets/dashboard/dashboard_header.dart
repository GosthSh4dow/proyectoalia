import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardHeader extends StatelessWidget {
  final String userName;
  final String? userPhotoUrl;
  final String branchName;
  final VoidCallback onMenuPressed;
  final VoidCallback onProfilePressed;

  const DashboardHeader({
    Key? key,
    required this.userName,
    this.userPhotoUrl,
    required this.branchName,
    required this.onMenuPressed,
    required this.onProfilePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onMenuPressed,
                icon: const Icon(Icons.menu_rounded, size: 28),
                color: Colors.black87,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              GestureDetector(
                onTap: onProfilePressed,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC026D3), width: 2), // Fuchsia primary
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: userPhotoUrl != null ? NetworkImage(userPhotoUrl!) : null,
                    child: userPhotoUrl == null 
                      ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U', 
                          style: GoogleFonts.poppins(color: const Color(0xFFC026D3), fontWeight: FontWeight.bold))
                      : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Greeting & Branch
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, $userName 👋',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                         Icon(Icons.store_mall_directory_rounded, size: 16, color: Colors.grey.shade500),
                         const SizedBox(width: 6),
                         Text(
                           branchName,
                           style: GoogleFonts.poppins(
                             fontSize: 14,
                             color: Colors.grey.shade500,
                             fontWeight: FontWeight.w500,
                           ),
                         ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
