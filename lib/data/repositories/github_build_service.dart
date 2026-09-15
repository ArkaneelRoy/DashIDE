import 'dart:convert';
import 'package:http/http.dart' as http;

class GitHubBuildService {
  final String owner;
  final String repo;
  final String token;

  GitHubBuildService({
    required this.owner,
    required this.repo,
    required this.token,
  });

  Future<bool> triggerWorkflow({
    String workflowId = 'build_app.yml',
    String ref = 'main',
  }) async {
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/actions/workflows/$workflowId/dispatches',
    );

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $token',
        'X-GitHub-Api-Version': '2022-11-28',
      },
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

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final runs = data['workflow_runs'] as List<dynamic>;
      if (runs.isNotEmpty) {
        return runs.first as Map<String, dynamic>;
      }
    }
    return null;
  }
}
