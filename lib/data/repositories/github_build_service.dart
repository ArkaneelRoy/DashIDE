import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

class GitHubBuildService {
  final String owner;
  final String repo;
  final String token;

  GitHubBuildService({
    required this.owner,
    required this.repo,
    required this.token,
  });

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  static const String multiTargetWorkflow = r'''name: Multi-Platform Flutter CI Build
on:
  workflow_dispatch:
    inputs:
      target:
        description: 'Build Target'
        required: true
        default: 'android-arm64'
        type: choice
        options:
          - android-arm64
          - android-armv7
          - linux
          - windows
          - macos

jobs:
  build-android:
    name: Build Android (${{ inputs.target }})
    if: startsWith(inputs.target, 'android')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
      - run: flutter pub get
      - name: Compile APK
        run: |
          if [ "${{ inputs.target }}" = "android-armv7" ]; then
            flutter build apk --release --target-platform=android-arm
          else
            flutter build apk --release --target-platform=android-arm64
          fi
      - uses: actions/upload-artifact@v4
        with:
          name: ${{ inputs.target }}-release
          path: build/app/outputs/flutter-apk/app-release.apk

  build-linux:
    name: Build Linux Desktop
    if: inputs.target == 'linux'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
      - run: |
          sudo apt-get update -y
          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
      - run: flutter pub get
      - run: flutter build linux --release
      - name: Package Linux Bundle
        run: tar -czf linux-release.tar.gz -C build/linux/x64/release/bundle .
      - uses: actions/upload-artifact@v4
        with:
          name: linux-release
          path: linux-release.tar.gz

  build-windows:
    name: Build Windows Desktop
    if: inputs.target == 'windows'
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
      - run: flutter pub get
      - run: flutter build windows --release
      - name: Package Windows Bundle
        shell: pwsh
        run: Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath windows-release.zip
      - uses: actions/upload-artifact@v4
        with:
          name: windows-release
          path: windows-release.zip

  build-macos:
    name: Build macOS Desktop
    if: inputs.target == 'macos'
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
      - run: flutter pub get
      - run: flutter build macos --release --no-codesign
      - name: Package macOS App
        run: |
          cd build/macos/Build/Products/Release
          zip -r -y macos-release.zip *.app
      - uses: actions/upload-artifact@v4
        with:
          name: macos-release
          path: build/macos/Build/Products/Release/macos-release.zip
''';

  Future<void> ensureRepoAndWorkflow({Function(String)? onStatus}) async {
    final repoUri = Uri.parse('https://api.github.com/repos/$owner/$repo');
    final repoRes = await http.get(repoUri, headers: _headers);

    if (repoRes.statusCode == 404) {
      onStatus?.call('Creating remote repository $owner/$repo...');
      final createRes = await http.post(
        Uri.parse('https://api.github.com/user/repos'),
        headers: _headers,
        body: jsonEncode({
          'name': repo,
          'description': 'Cross-platform app built via DashIDE',
          'private': false,
          'auto_init': true,
        }),
      );

      if (createRes.statusCode != 201) {
        throw Exception('Failed to create repo: ${createRes.body}');
      }
      onStatus?.call('Repository created: $owner/$repo');
      await Future.delayed(const Duration(seconds: 3));
    }

    final workflowUri = Uri.parse('https://api.github.com/repos/$owner/$repo/contents/.github/workflows/build_app.yml');
    final workflowRes = await http.get(workflowUri, headers: _headers);

    String? sha;
    if (workflowRes.statusCode == 200) {
      sha = jsonDecode(workflowRes.body)['sha'];
    }

    onStatus?.call('Configuring Multi-OS build workflow...');
    await http.put(
      workflowUri,
      headers: _headers,
      body: jsonEncode({
        'message': 'ci: update multi-os build workflow',
        'content': base64Encode(utf8.encode(multiTargetWorkflow)),
        if (sha != null) 'sha': sha,
      }),
    );
  }

  Future<void> syncWorkspaceFiles({
    required Directory localDir,
    Function(String)? onProgress,
  }) async {
    await ensureRepoAndWorkflow(onStatus: onProgress);

    if (!await localDir.exists()) {
      throw Exception('Project directory does not exist: ${localDir.path}');
    }

    final entities = localDir.listSync(recursive: true);
    for (final entity in entities) {
      if (entity is File) {
        final rel = entity.path.substring(localDir.path.length + 1).replaceAll('\\', '/');
        if (rel.startsWith('.git/') || rel.startsWith('build/')) continue;

        onProgress?.call('Syncing $rel...');
        final bytes = await entity.readAsBytes();
        final fileUrl = Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$rel');

        final checkRes = await http.get(fileUrl, headers: _headers);
        String? sha;
        if (checkRes.statusCode == 200) {
          sha = jsonDecode(checkRes.body)['sha'];
        }

        await http.put(
          fileUrl,
          headers: _headers,
          body: jsonEncode({
            'message': 'chore: update $rel',
            'content': base64Encode(bytes),
            if (sha != null) 'sha': sha,
          }),
        );
      }
    }
  }

  Future<bool> triggerWorkflow({
    String workflowFileName = 'build_app.yml',
    String target = 'android-arm64',
  }) async {
    final url = Uri.parse('https://api.github.com/repos/$owner/$repo/actions/workflows/$workflowFileName/dispatches');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'ref': 'main',
        'inputs': {'target': target},
      }),
    );
    return response.statusCode == 204;
  }

  Future<Map<String, dynamic>?> getLatestRun({String workflowFileName = 'build_app.yml'}) async {
    final url = Uri.parse('https://api.github.com/repos/$owner/$repo/actions/workflows/$workflowFileName/runs?per_page=1');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final runs = data['workflow_runs'] as List<dynamic>;
      if (runs.isNotEmpty) return runs.first as Map<String, dynamic>;
    }
    return null;
  }

  Future<List<dynamic>> getRunArtifacts(int runId) async {
    final url = Uri.parse('https://api.github.com/repos/$owner/$repo/actions/runs/$runId/artifacts');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['artifacts'] as List<dynamic>;
    }
    return [];
  }

  Future<void> downloadAndInstallArtifact({
    required String artifactDownloadUrl,
    required String target,
    Function(String)? onStatus,
  }) async {
    onStatus?.call('Downloading $target build artifact...');
    final response = await http.get(Uri.parse(artifactDownloadUrl), headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to download artifact: ${response.statusCode}');
    }

    final archive = ZipDecoder().decodeBytes(response.bodyBytes);
    final tempDir = await getTemporaryDirectory();

    // On Android, install the APK directly
    if (target.startsWith('android')) {
      for (final file in archive) {
        if (file.isFile && file.name.endsWith('.apk')) {
          final apkPath = '${tempDir.path}/${file.name}';
          final outFile = File(apkPath);
          await outFile.writeAsBytes(file.content as List<int>);
          onStatus?.call('Launching APK package installer...');
          await OpenFilex.open(apkPath);
          return;
        }
      }
    } else {
      // For desktop binaries (zip/tar.gz), save bundle to downloads/temp folder
      final bundlePath = '${tempDir.path}/$target-release.zip';
      final bundleFile = File(bundlePath);
      await bundleFile.writeAsBytes(response.bodyBytes);
      onStatus?.call('Saved $target binary bundle to: $bundlePath');
      await OpenFilex.open(bundlePath);
      return;
    }

    throw Exception('No valid build output found in artifact bundle');
  }
}
