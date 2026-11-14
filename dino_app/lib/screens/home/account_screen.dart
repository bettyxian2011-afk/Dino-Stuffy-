import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/account_repository.dart';
import '../../data/strata_services.dart';
import '../../models/user_profile.dart';
import '../../theme/strata_theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.accountRepository});

  final AccountRepository? accountRepository;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  UserProfile? _profile;
  Uint8List? _photoPreview;
  bool _loading = true;
  bool _savingName = false;
  bool _uploadingPhoto = false;
  String? _error;

  AccountRepository get _accounts =>
      widget.accountRepository ?? StrataServices.accountRepository;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _accounts.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _nameController.text = profile?.displayName ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your account. $error';
        _loading = false;
      });
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 80) {
      _showMessage('Use a name between 1 and 80 characters.');
      return;
    }
    setState(() => _savingName = true);
    try {
      await _accounts.updateDisplayName(name);
      if (!mounted) return;
      setState(() {
        final profile = _profile;
        if (profile != null) {
          _profile = UserProfile(
            uid: profile.uid,
            displayName: name,
            accountKind: profile.accountKind,
            createdAt: profile.createdAt,
            badgeCount: profile.badgeCount,
            friendCode: profile.friendCode,
            photoUrl: profile.photoUrl,
          );
        }
      });
      _showMessage('Name updated.');
    } catch (error) {
      _showMessage('Could not update your name. $error');
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePhoto() async {
    if (_uploadingPhoto) return;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = true;
        _photoPreview = bytes;
      });
      final photoURL = await _accounts.updateProfilePhoto(bytes);
      if (!mounted) return;
      setState(() {
        _photoPreview = null;
        final profile = _profile;
        if (profile != null) {
          _profile = UserProfile(
            uid: profile.uid,
            displayName: profile.displayName,
            accountKind: profile.accountKind,
            createdAt: profile.createdAt,
            badgeCount: profile.badgeCount,
            friendCode: profile.friendCode,
            photoUrl: photoURL,
          );
        }
      });
      _showMessage('Profile photo updated.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _photoPreview = null);
      _showMessage('Could not update your photo. $error');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _accounts.signOut();
      if (mounted) context.go('/onboarding');
    } catch (error) {
      _showMessage('Could not sign out. $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _photoAvatar() {
    final photo = _photoPreview;
    final url = _profile?.photoUrl;
    Widget content;
    if (photo != null) {
      content = Image.memory(
        photo,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _avatarFallback(),
      );
    } else if (url != null && url.isNotEmpty) {
      content = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _avatarFallback(),
      );
    } else {
      content = _avatarFallback();
    }
    return CircleAvatar(
      radius: 58,
      backgroundColor: const Color(0xFFE8DFD4),
      child: ClipOval(child: SizedBox(width: 116, height: 116, child: content)),
    );
  }

  Widget _avatarFallback() {
    final initial = _profile?.displayName.trim().isNotEmpty == true
        ? _profile!.displayName.trim()[0].toUpperCase()
        : 'S';
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.libreBaskerville(
          color: StrataColors.brown,
          fontSize: 42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StrataColors.cream,
      appBar: AppBar(
        backgroundColor: StrataColors.cream,
        title: Text(
          'Account',
          style: GoogleFonts.libreBaskerville(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _profile == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Sign in to manage your account.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/sign-in'),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              _photoAvatar(),
                              if (_uploadingPhoto)
                                const Positioned.fill(
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else
                                IconButton.filled(
                                  tooltip: 'Change profile photo',
                                  onPressed: _changePhoto,
                                  icon: const Icon(Icons.edit),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: TextButton.icon(
                            onPressed: _uploadingPhoto ? null : _changePhoto,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Change profile photo'),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Display name',
                          style: GoogleFonts.dmSans(
                            color: StrataColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          maxLength: 80,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Your name',
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _savingName ? null : _saveName,
                          style: FilledButton.styleFrom(
                            backgroundColor: StrataColors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: _savingName
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save name'),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
