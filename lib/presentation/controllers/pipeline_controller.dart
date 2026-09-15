import 'dart:async';
import 'dart:io';
import '../../data/repositories/github_build_service.dart';

class PipelineController {
  final GitHubBuildService service;
  final Function(String) onLog;
  final Function(String) onStatusChanged;

  PipelineController({
    required this.service,
    required this.onLog,
    required this.onStatusChanged,
  });

  Future<void> runPipeline(Directory projectDir) async {
    try {
      onStatusChanged('Syncing...');
      onLog('Syncing project files to GitHub...');
      await service.syncWorkspaceFiles(
        localDir: projectDir,
        onProgress: onLog,
      );

      onStatusChanged('Dispatching...');
      onLog('Dispatching GitHub Actions workflow...');
      final ok = await service.triggerWorkflow();
      if (!ok) {
        onStatusChanged('Error');
        onLog('Trigger failed. Check token permissions.');
        return;
      }

      onStatusChanged('Compiling...');
      _pollRun();
    } catch (e) {
      onStatusChanged('Failed');
      onLog('Pipeline failure: $e');
    }
  }

  void _pollRun() {
    int attempts = 0;
    Timer.periodic(const Duration(seconds: 6), (timer) async {
      attempts++;
      final run = await service.getLatestRun();
      if (run != null) {
        final status = run['status'];
        final conclusion = run['conclusion'];
        onLog('CI Run: $status (${conclusion ?? "active"})');

        if (status == 'completed') {
          timer.cancel();
          if (conclusion == 'success') {
            onStatusChanged('Downloading...');
            final runId = run['id'] as int;
            final artifacts = await service.getRunArtifacts(runId);
            if (artifacts.isNotEmpty) {
              await service.downloadAndInstallArtifact(
                artifactDownloadUrl: artifacts.first['archive_download_url'] as String,
                onStatus: onLog,
              );
              onStatusChanged('Ready');
            } else {
              onStatusChanged('No Artifact');
            }
          } else {
            onStatusChanged('Failed');
          }
        }
      }

      if (attempts >= 45) {
        timer.cancel();
        onStatusChanged('Timeout');
      }
    });
  }
}
