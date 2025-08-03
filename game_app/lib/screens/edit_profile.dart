// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:toastification/toastification.dart';

// class EditProfilePage extends StatefulWidget {
//   final String userId;
//   final Map<String, dynamic>? userData;

//   const EditProfilePage({super.key, required this.userId, this.userData});

//   @override
//   State<EditProfilePage> createState() => _EditProfilePageState();
// }

// class _EditProfilePageState extends State<EditProfilePage> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _firstNameController;
//   late TextEditingController _lastNameController;
//   late TextEditingController _emailController;
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _firstNameController = TextEditingController(text: widget.userData?['firstName']?.toString() ?? '');
//     _lastNameController = TextEditingController(text: widget.userData?['lastName']?.toString() ?? '');
//     _emailController = TextEditingController(text: widget.userData?['email']?.toString() ?? '');
//   }

//   @override
//   void dispose() {
//     _firstNameController.dispose();
//     _lastNameController.dispose();
//     _emailController.dispose();
//     super.dispose();
//   }

//   Future<void> _updateProfile() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isLoading = true);
//     try {
//       await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
//         'firstName': _firstNameController.text.trim(),
//         'lastName': _lastNameController.text.trim(),
//         'email': _emailController.text.trim(),
//         'updatedAt': Timestamp.now(),
//       });
//       toastification.show(
//         context: context,
//         type: ToastificationType.success,
//         title: const Text('Success'),
//         description: const Text('Profile updated successfully'),
//         autoCloseDuration: const Duration(seconds: 3),
//         backgroundColor: Colors.green,
//         foregroundColor: Colors.white,
//       );
//       Navigator.pop(context);
//     } catch (e) {
//       toastification.show(
//         context: context,
//         type: ToastificationType.error,
//         title: const Text('Error'),
//         description: Text('Failed to update profile: $e'),
//         autoCloseDuration: const Duration(seconds: 3),
//         backgroundColor: Colors.red,
//         foregroundColor: Colors.white,
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF0D1B2A),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF1B263B),
//         title: Text(
//           'Edit Profile',
//           style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               TextFormField(
//                 controller: _firstNameController,
//                 style: GoogleFonts.poppins(color: Colors.white),
//                 decoration: InputDecoration(
//                   labelText: 'First Name',
//                   labelStyle: GoogleFonts.poppins(color: Colors.white70),
//                   filled: true,
//                   fillColor: Colors.white.withOpacity(0.1),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please enter your first name';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _lastNameController,
//                 style: GoogleFonts.poppins(color: Colors.white),
//                 decoration: InputDecoration(
//                   labelText: 'Last Name',
//                   labelStyle: GoogleFonts.poppins(color: Colors.white70),
//                   filled: true,
//                   fillColor: Colors.white.withOpacity(0.1),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _emailController,
//                 style: GoogleFonts.poppins(color: Colors.white),
//                 decoration: InputDecoration(
//                   labelText: 'Email',
//                   labelStyle: GoogleFonts.poppins(color: Colors.white70),
//                   filled: true,
//                   fillColor: Colors.white.withOpacity(0.1),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//                 keyboardType: TextInputType.emailAddress,
//                 validator: (value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please enter your email';
//                   }
//                   if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
//                     return 'Please enter a valid email';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 24),
//               _isLoading
//                   ? const Center(child: CircularProgressIndicator(color: Colors.white))
//                   : ElevatedButton(
//                       onPressed: _updateProfile,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.blueAccent,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         minimumSize: const Size(double.infinity, 50),
//                       ),
//                       child: Text(
//                         'Save Changes',
//                         style: GoogleFonts.poppins(
//                           color: Colors.white,
//                           fontWeight: FontWeight.w500,
//                           fontSize: 16,
//                         ),
//                       ),
//                     ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }