import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

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
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $token',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  /// Syncs all files in [localDir] to the remote repository under [remoteRootPath]
  Future<void> syncWorkspaceFiles({
    required Directory localDir,
    required Function(String) onProgress,
    String remoteRootPath = 'demo_app',
  }) async {
    final entities = localDir.listSync(recursive: true);
    final files = entities.whereType<File>().toList();

    for (final file in files) {
      final relativePath = file.path.substring(localDir.path.length + 1);
      final remotePath = '$remoteRootPath/$relativePath';
      onProgress('Syncing: $remotePath');

      final contentBytes = await file.readAsBytes();
      final base64Content = base64Encode(contentBytes);

      // Check if file exists on GitHub to obtain its SHA (required for updates)
      final getUrl = Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$remotePath');
      final getRes = await http.get(getUrl, headers: _headers);

      String? sha;
      if (getRes.statusCode == 200) {
        final data = jsonDecode(getRes.body);
        sha = data['sha'];
      }

      final body = {
        'message': 'sync: update $remotePath from DashIDE',
        'content': base64Content,
        if (sha != null) 'sha': sha,
      };

      final putRes = await http.put(
        getUrl,
        headers: _headers,
        body: jsonEncode(body),
      );

      if (putRes.statusCode != 200 && putRes.statusCode != 201) {
        throw Exception('Failed to upload $remotePath: ${putRes.body}');
      }
    }
  }

  Future<bool> triggerWorkflow({
    String workflowId = 'build_app.yml',
    String ref = 'main',
  }) async {
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/actions/workflows/$workflowId/dispatches',
    );

    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'ref': ref}),
    );

    return response.statusCode == 204;
  }

  Future<Map<String, dynamic>?> getLatestRun({
    String workflowId = 'build_app.yml',
  }) async {
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/actions/workflows/$workflowId/runs?per_page=1',
    );

    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final runs = data['workflow_runs'] as List<dynamic>;
      if (runs.isNotEmpty) {
        return runs.first as Map<String, dynamic>;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getRunArtifacts(int runId) async {
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/actions/runs/$runId/artifacts',
    );

    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = data['artifacts'] as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Downloads artifact zip, extracts .apk, and prompts Android Package Installer
  Future<void> downloadAndInstallArtifact({
    required String artifactDownloadUrl,
    required Function(String) onStatus,
  }) async {
    onStatus('Downloading build artifact zip...');
    final response = await http.get(Uri.parse(artifactDownloadUrl), headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Artifact download failed with status ${response.statusCode}');
    }

    onStatus('Extracting APK payload...');
    final bytes = response.bodyBytes;
    final archive = ZipDecoder().decodeBytes(bytes);

    final tempDir = await getTemporaryDirectory();
    File? extractedApk;

    for (final file in archive) {
      if (file.isFile && file.name.endsWith('.apk')) {
        final outFile = File('${tempDir.path}/${file.name}');
        await outFile.writeAsBytes(file.content as List<int>);
        extractedApk = outFile;
        break;
      }
    }

    if (extractedApk == null) {
      throw Exception('No APK found inside artifact archive.');
    }

    onStatus('Opening package installer for: ${extractedApk.path.split("/").last}');
    await OpenFilex.open(
      extractedApk.path,
      type: 'application/vnd.android.package-archive',
    );
  }
}
