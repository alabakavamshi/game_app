import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';

class ManagePlayersPage extends StatefulWidget {
  final String userId;

  const ManagePlayersPage({super.key, required this.userId});

  @override
  State<ManagePlayersPage> createState() => _ManagePlayersPageState();
}

class _ManagePlayersPageState extends State<ManagePlayersPage> {
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
  }

  Future<void> _fetchParticipants() async {
    setState(() => _isLoading = true);
    try {
      final tournamentsQuery = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('createdBy', isEqualTo: widget.userId)
          .get();

      final List<Map<String, dynamic>> allParticipants = [];
      for (var doc in tournamentsQuery.docs) {
        final data = doc.data();
        final participants = List<Map<String, dynamic>>.from(data['participants'] ?? []);
        for (var participant in participants) {
          // Fetch user details from users collection
          final userId = participant['id']?.toString() ?? '';
          String name = 'Unknown';
          String email = '';

          if (userId.isNotEmpty) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
            if (userDoc.exists) {
              final userData = userDoc.data();
              name = userData?['firstName']?.toString().isNotEmpty == true
                  ? '${userData!['firstName'].toString().capitalize()} ${userData['lastName']?.toString().isNotEmpty == true ? userData['lastName'].toString().capitalize() : ''}'.trim()
                  : 'Unknown';
              email = userData?['email']?.toString() ?? '';
            }
          }

          allParticipants.add({
            'tournamentId': doc.id,
            'tournamentName': data['name']?.toString() ?? 'Unnamed Tournament',
            'userId': userId,
            'name': name,
            'email': email,
            'gender': participant['gender']?.toString() ?? 'Unknown',
            'score': participant['score']?.toInt() ?? 0,
          });
        }
      }

      setState(() {
        _participants = allParticipants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load participants: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeParticipant(String tournamentId, String userId) async {
    try {
      final tournamentDoc = FirebaseFirestore.instance.collection('tournaments').doc(tournamentId);
      await tournamentDoc.update({
        'participants': FieldValue.arrayRemove([
          {'id': userId, 'gender': _participants.firstWhere((p) => p['userId'] == userId && p['tournamentId'] == tournamentId)['gender'], 'score': 0}
        ])
      });
      setState(() {
        _participants.removeWhere((p) => p['tournamentId'] == tournamentId && p['userId'] == userId);
      });
      toastification.show(
        context: context,
        type: ToastificationType.success,
        title: Text(
          'Success',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            color: const Color(0xFFFDFCFB), // Background
          ),
        ),
        description: Text(
          'Participant removed',
          style: GoogleFonts.poppins(
            color: const Color(0xFFFDFCFB), // Background
          ),
        ),
        autoCloseDuration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF2A9D8F), // Success
      );
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: Text(
          'Error',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            color: const Color(0xFFFDFCFB), // Background
          ),
        ),
        description: Text(
          'Failed to remove participant: $e',
          style: GoogleFonts.poppins(
            color: const Color(0xFFFDFCFB), // Background
          ),
        ),
        autoCloseDuration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFFE76F51), // Error
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB), // Background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Manage Players',
          style: GoogleFonts.poppins(
            color: const Color(0xFF333333), // Text Primary
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF757575)), // Text Secondary
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C9A8B), Color(0xFFC1DADB)], // Primary to Secondary
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF4A261))) // Accent
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(color: const Color(0xFFE76F51), fontSize: 16), // Error
                  ),
                )
              : _participants.isEmpty
                  ? Center(
                      child: Text(
                        'No participants found',
                        style: GoogleFonts.poppins(color: const Color(0xFF757575), fontSize: 16), // Text Secondary
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _participants.length,
                      itemBuilder: (context, index) {
                        final participant = _participants[index];
                        return Card(
                          color: const Color(0xFFFFFFFF), // Surface
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                          shadowColor: const Color(0xFF1D3557).withOpacity(0.2), // Deep Indigo
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              participant['name'],
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF333333), // Text Primary
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  participant['email'].isNotEmpty ? participant['email'] : 'No email available',
                                  style: GoogleFonts.poppins(color: const Color(0xFF757575), fontSize: 12), // Text Secondary
                                ),
                                Text(
                                  'Tournament: ${participant['tournamentName']}',
                                  style: GoogleFonts.poppins(color: const Color(0xFF757575), fontSize: 12), // Text Secondary
                                ),
                                Text(
                                  'Gender: ${participant['gender']}',
                                  style: GoogleFonts.poppins(color: const Color(0xFF757575), fontSize: 12), // Text Secondary
                                ),
                                Text(
                                  'Score: ${participant['score']}',
                                  style: GoogleFonts.poppins(color: const Color(0xFF757575), fontSize: 12), // Text Secondary
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Color(0xFFE76F51)), // Error
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFFFFFFFF), // Surface
                                    title: Text(
                                      'Remove Participant',
                                      style: GoogleFonts.poppins(color: const Color(0xFF333333)), // Text Primary
                                    ),
                                    content: Text(
                                      'Remove ${participant['name']} from ${participant['tournamentName']}?',
                                      style: GoogleFonts.poppins(color: const Color(0xFF757575)), // Text Secondary
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: Text(
                                          'Cancel',
                                          style: GoogleFonts.poppins(color: const Color(0xFF757575)), // Text Secondary
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE76F51)), // Error
                                        child: Text(
                                          'Remove',
                                          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)), // Background
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _removeParticipant(participant['tournamentId'], participant['userId']);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}