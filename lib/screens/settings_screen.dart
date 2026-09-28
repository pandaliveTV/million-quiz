import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ad_service.dart';
import '../services/iap_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StorageService>();
    final iap = context.read<IapService>();
    final ads = context.read<AdService>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('الإعدادات')),
      body: StageBackground(
        intensity: 0.15,
        child: SafeArea(
          child: ListView(
            children: [
              SwitchListTile(
                title: const Text('الأصوات'),
                secondary: Icon(s.muted ? Icons.volume_off : Icons.volume_up),
                value: !s.muted,
                onChanged: (v) => s.setMuted(!v),
              ),
              SwitchListTile(
                title: const Text('الموسيقى'),
                secondary: const Icon(Icons.music_note),
                value: s.music,
                onChanged: s.muted ? null : s.setMusic,
              ),
              SwitchListTile(
                title: const Text('الاهتزاز'),
                secondary: const Icon(Icons.vibration),
                value: s.vibration,
                onChanged: s.setVibration,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(
                  s.adsRemoved
                      ? 'تمت إزالة الإعلانات — شكراً لك!'
                      : 'إزالة الإعلانات',
                ),
                subtitle: s.adsRemoved
                    ? null
                    : Text(
                        iap.product?.price != null
                            ? '${iap.product!.price} — تبقى إعلانات المكافأة الاختيارية فقط'
                            : 'تزيل البانر والإعلانات الكاملة. تبقى إعلانات المكافأة الاختيارية.',
                      ),
                onTap: s.adsRemoved
                    ? null
                    : () async {
                        final ok = await iap.buyRemoveAds();
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('المتجر غير متاح حالياً'),
                            ),
                          );
                        }
                      },
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('استعادة المشتريات'),
                onTap: iap.restore,
              ),
              const Divider(),
              _PrivacyOptionsTile(ads: ads),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('سياسة الخصوصية'),
                onTap: () => launchUrl(
                  Uri.parse(privacyPolicyUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('مسابقة المليون — EliteP'),
                subtitle: Text('الإصدار 1.0.0 • الجوائز افتراضية للتسلية فقط'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Consent (UMP) re-entry point, shown only where the regulation requires it.
class _PrivacyOptionsTile extends StatefulWidget {
  final AdService ads;
  const _PrivacyOptionsTile({required this.ads});

  @override
  State<_PrivacyOptionsTile> createState() => _PrivacyOptionsTileState();
}

class _PrivacyOptionsTileState extends State<_PrivacyOptionsTile> {
  late final Future<bool> _required = widget.ads
      .privacyOptionsRequired()
      .catchError((_) => false);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _required,
      builder: (context, snap) => snap.data == true
          ? ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('خيارات الخصوصية والموافقة'),
              onTap: widget.ads.showPrivacyOptions,
            )
          : const SizedBox.shrink(),
    );
  }
}
