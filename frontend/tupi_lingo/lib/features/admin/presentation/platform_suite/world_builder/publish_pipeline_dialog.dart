import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/security/encryption_center.dart';

/// Modal do Pipeline de Publicação e Visual Diff do World Builder CMS (RFC-013 Capítulo 19).
class PublishPipelineDialog extends StatefulWidget {
  final Map<String, dynamic> worldBundle;
  final Future<void> Function(String commitMessage, String authorRole, String versionTag) onConfirmPublish;

  const PublishPipelineDialog({
    super.key,
    required this.worldBundle,
    required this.onConfirmPublish,
  });

  @override
  State<PublishPipelineDialog> createState() => _PublishPipelineDialogState();
}

class _PublishPipelineDialogState extends State<PublishPipelineDialog> {
  final _commitController = TextEditingController(text: 'Expansão curricular e refinamento topológico de rios');
  String _authorRole = 'Historiador & Curador Linguístico';
  String _versionTag = '1.2.0';
  bool _isSubmitting = false;
  late String _diffHash;

  @override
  void initState() {
    super.initState();
    _diffHash = EncryptionCenter.instance.generateSnapshotHash(widget.worldBundle);
  }

  @override
  void dispose() {
    _commitController.dispose();
    super.dispose();
  }

  Future<void> _handlePublish() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.onConfirmPublish(
        _commitController.text.trim(),
        _authorRole,
        _versionTag,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao publicar: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final territories = (widget.worldBundle['territories'] as List?)?.length ?? 0;
    final villages = (widget.worldBundle['villages'] as List?)?.length ?? 0;
    final rivers = (widget.worldBundle['rivers'] as List?)?.length ?? 0;
    final trails = (widget.worldBundle['trails'] as List?)?.length ?? 0;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF334155), width: 1.5),
      ),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.rocket_launch, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pipeline de Publicação do Mundo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Gera snapshot imutável para consumo dinâmico no mobile',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF334155)),
            const SizedBox(height: 16),

            // Resumo das Entidades no Snapshot
            const Text(
              'Resumo do Snapshot Topológico',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildEntityBadge('Territórios', '$territories', const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _buildEntityBadge('Aldeias', '$villages', const Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                _buildEntityBadge('Rios Bézier', '$rivers', const Color(0xFFA78BFA)),
                const SizedBox(width: 8),
                _buildEntityBadge('Trilhas', '$trails', const Color(0xFFF59E0B)),
              ],
            ),
            const SizedBox(height: 16),

            // Hash SHA-256 de integridade
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SHA-256 SNAPSHOT DIFF HASH',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _diffHash,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Versão & Papel do Autor
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Versão do Snapshot', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      const SizedBox(height: 6),
                      TextFormField(
                        initialValue: _versionTag,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _inputStyle('1.2.0'),
                        onChanged: (v) => _versionTag = v,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Papel do Autor', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _authorRole,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: _inputStyle(''),
                        items: const [
                          DropdownMenuItem(value: 'Historiador & Curador Linguístico', child: Text('Curador Histórico')),
                          DropdownMenuItem(value: 'Linguista Tupi', child: Text('Linguista Tupi')),
                          DropdownMenuItem(value: 'Engenheiro de Conteúdo', child: Text('Engenheiro de Conteúdo')),
                          DropdownMenuItem(value: 'Administrador de Plataforma', child: Text('Administrador')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _authorRole = v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mensagem de Commit
            const Text('Mensagem de Release / Commit', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _commitController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: _inputStyle('Descreva as alterações curriculares e territoriais'),
            ),
            const SizedBox(height: 24),

            // Ações do Dialog
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(_isSubmitting ? 'Publicando...' : 'Publicar Versão do Mundo'),
                  onPressed: _isSubmitting ? null : _handlePublish,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityBadge(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'monospace'),
            ),
            Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF10B981)),
      ),
    );
  }
}
