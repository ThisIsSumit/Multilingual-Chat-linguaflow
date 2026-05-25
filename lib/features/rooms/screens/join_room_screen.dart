import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/rooms_bloc.dart';
import '../bloc/rooms_event.dart';
import '../bloc/rooms_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_button.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _codeController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Room code must be 6 characters');
      return;
    }
    setState(() => _error = null);
    context.read<RoomsBloc>().add(JoinRoom(code));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RoomsBloc, RoomsState>(
      listener: (context, state) {
        if (state is RoomJoinedSuccess) {
          Navigator.pushReplacementNamed(context, '/chat', arguments: state.room);
        } else if (state is RoomJoinError) {
          setState(() => _error = state.message);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            AppStrings.joinRoom,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Join a room',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-character code shared by the room creator.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  color: AppColors.primary,
                ),
                decoration: InputDecoration(
                  hintText: 'XXXXXX',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                    color: AppColors.primary.withOpacity(0.2),
                  ),
                  filled: true,
                  fillColor: AppColors.primary.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  errorText: _error,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  counterText: '',
                ),
                onChanged: (v) {
                  if (_error != null) setState(() => _error = null);
                  final upper = v.toUpperCase();
                  if (upper != v) {
                    _codeController.value = TextEditingValue(
                      text: upper,
                      selection: TextSelection.collapsed(offset: upper.length),
                    );
                  }
                },
              ),
              const SizedBox(height: 28),
              BlocBuilder<RoomsBloc, RoomsState>(
                builder: (context, state) => AppButton(
                  label: 'Join Room',
                  onPressed: state is RoomJoining ? null : () => _submit(context),
                  isLoading: state is RoomJoining,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
