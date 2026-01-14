part of '../page.dart';

class _ProfileSection extends StatefulWidget {
  const _ProfileSection();

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Kasir Super',
    packageName: 'Unknown',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

  String _patchInfo = '';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    _initPatchInfo();
  }

  Future<void> _initPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _packageInfo = info;
      });
    } catch (e) {
      print('Error getting PackageInfo: $e');
    }
  }

  Future<void> _initPatchInfo() async {
    try {
      // Import perlu ditambahkan di file utama
      final updater = ShorebirdUpdater();
      final currentPatch = await updater.readCurrentPatch();
      setState(() {
        _patchInfo = currentPatch != null
            ? 'Patch: ${currentPatch.number}'
            : 'Original';
      });
    } catch (e) {
      setState(() {
        _patchInfo = 'Original';
      });
      print('Error getting patch info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Dimens.defaultSize),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.dp50),
            child: Image.asset(
              'assets/icons/app_icon.png',
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          Dimens.dp16.width,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RegularText.semiBold(
                  _packageInfo.appName.isEmpty ||
                          _packageInfo.appName == 'Unknown'
                      ? 'Kasir Super'
                      : _packageInfo.appName,
                ),
                Dimens.dp4.height,
                RegularText(
                  'v${_packageInfo.version == 'Unknown' ? '1.0.0' : _packageInfo.version} (${_packageInfo.buildNumber == 'Unknown' ? '1' : _packageInfo.buildNumber})',
                  style: const TextStyle(
                    fontSize: Dimens.dp12,
                    color: Colors.grey,
                  ),
                ),
                if (_patchInfo.isNotEmpty) ...[
                  Dimens.dp2.height,
                  RegularText(
                    _patchInfo,
                    style: const TextStyle(
                      fontSize: Dimens.dp10,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
