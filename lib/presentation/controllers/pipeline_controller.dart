import 'dart:async';
import 'dart:io';
import '../../data/repositories/github_build_service.dart';

class PipelineController {
  final GitHubBuildService service;
  final String target;
  final Function(String) onLog;
  final Function(String) onStatusChanged;

  PipelineController({
    required this.service,
    this.target = 'android-arm64',
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
      onLog('Dispatching build for target: $target...');
      final ok = await service.triggerWorkflow(target: target);
      if (!ok) {
        onStatusChanged('Error');
        onLog('Workflow trigger failed. Check token permissions.');
        return;
      }

      onStatusChanged('Compiling...');
      onLog('Build job dispatched. Polling runner status...');
      await Future.delayed(const Duration(seconds: 4));
      _pollRun();
    } catch (e) {
      onStatusChanged('Failed');
      onLog('Pipeline failure: $e');
    }
  }

  void _pollRun() {
    int attempts = 0;
    const maxAttempts = 90;

    Timer.periodic(const Duration(seconds: 6), (timer) async {
      attempts++;
      final run = await service.getLatestRun();
      if (run != null) {
        final status = run['status'];
        final conclusion = run['conclusion'];
        final elapsed = (attempts * 6) ~/ 60;
        onLog('CI ($target): $status (${conclusion ?? "running, ~${elapsed}m"})');

        if (status == 'completed') {
          timer.cancel();
          if (conclusion == 'success') {
            onStatusChanged('Downloading...');
            final runId = run['id'] as int;
            final artifacts = await service.getRunArtifacts(runId);
            if (artifacts.isNotEmpty) {
              await service.downloadAndInstallArtifact(
                artifactDownloadUrl: artifacts.first['archive_download_url'] as String,
                target: target,
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

      if (attempts >= maxAttempts) {
        timer.cancel();
        onStatusChanged('Timeout');
      }
    });
  }
}
