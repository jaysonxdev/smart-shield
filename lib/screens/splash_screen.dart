import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  final Widget Function() onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _videoController = VideoPlayerController.asset('assets/videos/intro.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _videoController.play();
        _videoController.addListener(_onProgress);
      }).catchError((_) {
        if (!_navigated) {
          _navigated = true;
          _navigate();
        }
      });
  }

  void _onProgress() {
    if (!_videoController.value.isInitialized) return;

    final duration = _videoController.value.duration;
    final position = _videoController.value.position;

    if (duration.inMilliseconds == 0) return;

    // Fade in the black overlay + text during the final second
    if ((duration - position).inMilliseconds <= 1000 &&
        _fadeController.status == AnimationStatus.dismissed) {
      _fadeController.forward();
    }

    // Detect end of playback
    if (!_videoController.value.isPlaying &&
        position.inMilliseconds >= duration.inMilliseconds - 200 &&
        !_navigated) {
      _navigated = true;
      _navigate();
    }
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.onComplete()),
      );
    }
  }

  @override
  void dispose() {
    _videoController.removeListener(_onProgress);
    _videoController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoController.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController.value.size.width,
                height: _videoController.value.size.height,
                child: VideoPlayer(_videoController),
              ),
            ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Not everyone can afford a cybersecurity analyst, '
                        'but everyone should have access to one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '— SmartShield',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
