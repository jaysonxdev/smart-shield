import 'package:flutter/material.dart';
import '../theme_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo + app name
            Image.asset('assets/ui/logo.png', width: 72, height: 72),
            const SizedBox(height: 14),
            Text(
              'SmartShield',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: context.primaryText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),

            // Tagline
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              decoration: BoxDecoration(
                color: context.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.cardBorder),
              ),
              child: Text(
                '"Not everyone can afford a cybersecurity analyst, '
                'but everyone should have access to one."',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: context.secondaryText,
                  height: 1.55,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // What the app does
            _SectionCard(
              icon: Icons.security_outlined,
              title: 'What SmartShield does',
              children: [
                _Feature(
                  icon: Icons.biotech_outlined,
                  label: 'VirusTotal file scanning',
                  detail:
                      'Checks downloaded files against 70+ antivirus engines '
                      'using the VirusTotal API before you open them.',
                ),
                _Feature(
                  icon: Icons.psychology_outlined,
                  label: 'AI-powered permission monitoring',
                  detail:
                      'An AI assistant reviews every app\'s permissions and '
                      'explains in plain language what they can access and why '
                      'that may or may not be a risk.',
                ),
                _Feature(
                  icon: Icons.visibility_off_outlined,
                  label: 'Hidden app & scam-pattern detection',
                  detail:
                      'Identifies apps that are hidden from your home screen, '
                      'hold device-admin privileges, or use accessibility '
                      'services — the same techniques scam apps rely on.',
                ),
                _Feature(
                  icon: Icons.delete_sweep_outlined,
                  label: 'Junk file cleanup',
                  detail:
                      'Finds and removes residual cache, temporary, and '
                      'duplicate files to free up storage and reduce clutter.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Purpose
            _SectionCard(
              icon: Icons.favorite_border_outlined,
              title: 'Who it\'s built for',
              children: [
                _BodyText(
                  'SmartShield was created with elderly users in mind — '
                  'people who deserve the same level of digital protection as '
                  'anyone else, but who may not have the technical background '
                  'to spot a scam app, a dangerous file, or a permission that '
                  'shouldn\'t be there.',
                ),
                const SizedBox(height: 10),
                _BodyText(
                  'Scammers specifically target people who are less familiar '
                  'with modern technology. SmartShield puts a knowledgeable '
                  'guardian on every device — one that explains threats in '
                  'plain language and acts immediately when something looks wrong.',
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Credit
            Text(
              'Developed by Jayson Savio Patrick',
              style: TextStyle(
                fontSize: 13,
                color: context.subtleText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Built with Flutter · Powered by VirusTotal & Groq',
              style: TextStyle(fontSize: 12, color: context.subtleText),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;

  const _Feature({
    required this.icon,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              icon,
              size: 15,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.primaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: context.secondaryText,
        height: 1.55,
      ),
    );
  }
}
