import 'package:flutter/material.dart';
import 'sqlite_diagnostics.dart';

/// Página temporal para diagnóstico de SQLite
/// TEMPORAL: Eliminar después de diagnosticar el problema
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  Map<String, dynamic>? _results;
  bool _isRunning = false;

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _results = null;
    });

    try {
      final results = await SQLiteDiagnostics.runDiagnostics();
      SQLiteDiagnostics.printResults(results);

      setState(() {
        _results = results;
      });
    } catch (e) {
      setState(() {
        _results = {'error': e.toString()};
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SQLite Diagnostics'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: _isRunning ? null : _runDiagnostics,
                child: _isRunning
                    ? const Text('Running...')
                    : const Text('RUN DIAGNOSTICS'),
              ),
              const SizedBox(height: 24),
              if (_results != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildResults(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_results == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          'SQLite Version',
          _results!['sqlite_version']?.toString() ?? 'Unknown',
        ),
        const Divider(height: 32),
        _buildSection(
          'FTS Support',
          _buildFtsStatus(),
        ),
        const Divider(height: 32),
        if (_results!['fts5_error'] != null) ...[
          _buildSection(
            'FTS5 Error',
            _results!['fts5_error'].toString(),
            isError: true,
          ),
          const Divider(height: 32),
        ],
        if (_results!['modules'] != null) ...[
          _buildSection(
            'Available Modules',
            _buildModulesList(),
          ),
          const Divider(height: 32),
        ],
        if (_results!['compile_options'] != null) ...[
          _buildSection(
            'Compile Options (FTS)',
            _buildCompileOptions(),
          ),
        ],
      ],
    );
  }

  Widget _buildSection(String title, dynamic content, {bool isError = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (content is Widget)
          content
        else
          Text(
            content.toString(),
            style: TextStyle(
              fontSize: 14,
              color: isError ? Colors.red : Colors.black87,
              fontFamily: 'monospace',
            ),
          ),
      ],
    );
  }

  Widget _buildFtsStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusRow('FTS3', _results!['fts3_available'] == true),
        _buildStatusRow('FTS4', _results!['fts4_available'] == true),
        _buildStatusRow('FTS5', _results!['fts5_available'] == true),
      ],
    );
  }

  Widget _buildStatusRow(String name, bool available) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            available ? Icons.check_circle : Icons.cancel,
            color: available ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildModulesList() {
    final modules = _results!['modules'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: modules.map((m) => Text('• $m')).toList(),
    );
  }

  Widget _buildCompileOptions() {
    final options = (_results!['compile_options'] as List)
        .where((opt) => opt.toString().contains('FTS'))
        .toList();

    if (options.isEmpty) {
      return const Text('(No FTS-related options found)');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: options.map((opt) => Text('• $opt')).toList(),
    );
  }
}
