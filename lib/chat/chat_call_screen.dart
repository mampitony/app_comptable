// lib/chat/chat_call_screen.dart
//
// Deux écrans :
//  - ChatCallScreen : « Rejoindre » un appel déjà en cours (surtout en groupe).
//  - ChatWaitingCallScreen : appel sortant quand l'autre personne n'est pas
//    encore enregistrée pour la sonnerie. L'appel s'ouvre quand même :
//    « Appel » s'affiche jusqu'à l'arrivée de l'autre personne, puis la
//    minuterie démarre. Sans réponse après 60 secondes, l'appel s'arrête et
//    la discussion affiche « Appel manqué ».
//
// Les appels qui sonnent (personnes enregistrées) passent, eux, par
// ChatCallService (écran géré par ZEGOCLOUD).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import 'chat_call_config.dart';
import 'chat_call_service.dart';
import 'chat_service.dart';

// ======================================================================
// Rejoindre un appel en cours
// ======================================================================

class ChatCallScreen extends StatefulWidget {
  final String conversationId;

  /// Identifiant du message d'appel (identifie l'appel en cours).
  final String messageId;
  final bool isGroup;
  final bool video;

  const ChatCallScreen({
    super.key,
    required this.conversationId,
    required this.messageId,
    required this.isGroup,
    required this.video,
  });

  @override
  State<ChatCallScreen> createState() => _ChatCallScreenState();
}

class _ChatCallScreenState extends State<ChatCallScreen> {
  late final String _callId =
      ChatCallService.callIdFor(widget.conversationId, widget.messageId);

  @override
  void initState() {
    super.initState();
    ChatCallService.instance.currentCallId = _callId;
  }

  @override
  Widget build(BuildContext context) {
    final service = ChatService.instance;
    final me = service.memberId;

    if (!zegoConfigured || me == null) {
      return const _CallNotConfigured();
    }

    return ZegoUIKitPrebuiltCall(
      appID: zegoAppID,
      appSign: zegoAppSign,
      userID: ChatCallService.zegoId(me),
      userName: service.memberById(me).fullName,
      callID: _callId,
      config: ChatCallService.configFor(
        video: widget.video,
        group: widget.isGroup,
      ),
      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: ChatCallService.instance.handleCallEnd,
      ),
    );
  }
}

// ======================================================================
// Appel sortant en attente (« Appel » -> minuterie à l'arrivée de l'autre)
// ======================================================================

class ChatWaitingCallScreen extends StatefulWidget {
  final String conversationId;
  final String messageId;
  final bool isGroup;
  final bool video;

  /// Nom affiché pendant l'attente (contact ou groupe).
  final String title;

  const ChatWaitingCallScreen({
    super.key,
    required this.conversationId,
    required this.messageId,
    required this.isGroup,
    required this.video,
    required this.title,
  });

  @override
  State<ChatWaitingCallScreen> createState() => _ChatWaitingCallScreenState();
}

class _ChatWaitingCallScreenState extends State<ChatWaitingCallScreen> {
  late final String _callId =
      ChatCallService.callIdFor(widget.conversationId, widget.messageId);

  /// true dès qu'une autre personne est dans l'appel.
  final ValueNotifier<bool> _connected = ValueNotifier<bool>(false);

  /// Durée de l'appel, comptée à partir de l'arrivée de l'autre personne.
  final ValueNotifier<Duration> _elapsed = ValueNotifier<Duration>(Duration.zero);

  Timer? _poll;
  Timer? _timeout;
  DateTime? _connectedAt;
  bool _closing = false;
  Widget? _callView;

  @override
  void initState() {
    super.initState();
    ChatCallService.instance.currentCallId = _callId;
    _poll = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _checkRemote(),
    );
    _timeout = Timer(
      const Duration(seconds: ChatCallService.ringSeconds),
      _onTimeout,
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _timeout?.cancel();
    _connected.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------

  void _checkRemote() {
    if (_closing) return;
    bool hasRemote = false;
    try {
      hasRemote = ZegoUIKit().getRemoteUsers().isNotEmpty;
    } catch (_) {}

    if (hasRemote && !_connected.value) {
      _connectedAt = DateTime.now();
      _timeout?.cancel();
      _connected.value = true;
    }
    if (_connected.value && _connectedAt != null) {
      _elapsed.value = DateTime.now().difference(_connectedAt!);
    }
  }

  /// 60 secondes sans personne : l'appel s'arrête (« Appel manqué »).
  Future<void> _onTimeout() async {
    if (_connected.value || _closing) return;
    _closing = true;
    await ChatCallService.instance
        .closeUnanswered(widget.conversationId, widget.messageId);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      const SnackBar(content: Text("Personne n'a répondu à l'appel.")),
    );
  }

  /// Raccrocher avant que quelqu'un réponde.
  Future<void> _hangUpWhileRinging() async {
    if (_closing) return;
    _closing = true;
    await ChatCallService.instance
        .closeUnanswered(widget.conversationId, widget.messageId);
    if (mounted) Navigator.of(context).pop();
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  // ------------------------------------------------------------------

  Widget _buildCall(String me, String myName) {
    return ZegoUIKitPrebuiltCall(
      appID: zegoAppID,
      appSign: zegoAppSign,
      userID: ChatCallService.zegoId(me),
      userName: myName,
      callID: _callId,
      config: ChatCallService.configFor(
        video: widget.video,
        group: widget.isGroup,
        showDuration: false, // la durée est affichée par cet écran
      ),
      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: ChatCallService.instance.handleCallEnd,
      ),
    );
  }

  Widget _ringingOverlay() {
    return Container(
      color: const Color(0xFF0B141A),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Appel',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const Spacer(),
            const CircleAvatar(
              radius: 72,
              backgroundColor: Color(0xFF262A56),
              child: Icon(Icons.person, size: 84, color: Color(0xFFB39DFF)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _hangUpWhileRinging,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE5173F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_end, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Raccrocher',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _durationLabel() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Center(
            child: ValueListenableBuilder<Duration>(
              valueListenable: _elapsed,
              builder: (_, d, __) => Text(
                _format(d),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ChatService.instance;
    final me = service.memberId;

    if (!zegoConfigured || me == null) {
      return const _CallNotConfigured();
    }
    _callView ??= _buildCall(me, service.memberById(me).fullName);

    return ValueListenableBuilder<bool>(
      valueListenable: _connected,
      builder: (context, connected, _) {
        return PopScope(
          // Avant la réponse, « retour » = raccrocher.
          canPop: connected,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _hangUpWhileRinging();
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Positioned.fill(child: _callView!),
                if (!connected) Positioned.fill(child: _ringingOverlay()),
                if (connected) _durationLabel(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ======================================================================

class _CallNotConfigured extends StatelessWidget {
  const _CallNotConfigured();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appel')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Les appels ne sont pas encore configurés. Renseignez l'AppID "
            "et l'AppSign ZEGOCLOUD dans chat_call_config.dart.",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
