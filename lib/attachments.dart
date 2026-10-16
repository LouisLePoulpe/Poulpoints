import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cloud/supabase_cloud.dart';

class Attachments extends StatefulWidget {
  const Attachments({
    super.key,
    required this.taskId,
    required this.cloud,
    required this.synchronize,
    required this.done,
  });
  final String taskId;
  final SupabaseCloud? cloud;
  final Future<void> Function() synchronize;
  final bool done;
  @override
  State<Attachments> createState() => _AttachmentsState();
}

class _AttachmentsState extends State<Attachments> {
  List<Map<String, dynamic>> items = [];
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(Attachments old) {
    super.didUpdateWidget(old);
    if (old.taskId != widget.taskId ||
        old.cloud != widget.cloud ||
        old.done != widget.done) {
      load();
    }
  }

  Future<void> load() async {
    if (widget.cloud?.signedIn != true || widget.done) {
      if (mounted) setState(() => items = []);
      return;
    }
    final cloud = widget.cloud!;
    final taskId = widget.taskId;
    try {
      final data = await cloud.attachmentAction('list', taskId);
      if (mounted &&
          widget.cloud == cloud &&
          widget.taskId == taskId &&
          !widget.done) {
        setState(() {
          items = (data['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Pièces jointes indisponibles. Vérifiez la connexion et synchronisez la tâche.',
        );
      }
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Impossible de transférer le fichier. Limites : 10 Mo par fichier, 10 fichiers par tâche, 100 Mo par compte.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> add() async {
    await perform(() async {
      final cloud = widget.cloud!;
      final taskId = widget.taskId;
      final file = await openFile();
      if (file == null || !mounted) return;
      final length = await file.length();
      if (length == 0 || length > 10 * 1024 * 1024) {
        throw StateError('Taille de fichier invalide');
      }
      await widget.synchronize();
      if (!mounted ||
          widget.cloud != cloud ||
          widget.taskId != taskId ||
          widget.done) {
        return;
      }
      await cloud.uploadAttachment(taskId, file.name, await file.readAsBytes());
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Text('Pièces jointes', style: Theme.of(context).textTheme.titleMedium),
      if (widget.cloud?.signedIn != true)
        const Text('Connectez-vous au cloud pour joindre des fichiers.')
      else if (widget.done)
        const Text(
          'Les copies cloud sont supprimées après synchronisation de la tâche terminée.',
        )
      else ...[
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(item['name'] as String),
            subtitle: Text('${((item['size'] as num) / 1024).ceil()} Ko'),
            onTap: busy
                ? null
                : () => perform(() async {
                    final data = await widget.cloud!.attachmentAction(
                      'open',
                      widget.taskId,
                      id: item['id'] as String,
                    );
                    final uri = Uri.parse(data['url'] as String);
                    if (uri.scheme != 'https' ||
                        uri.host != Uri.parse(widget.cloud!.url).host ||
                        !await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        )) {
                      throw StateError('Ouverture impossible');
                    }
                  }),
            trailing: IconButton(
              tooltip: 'Supprimer la copie cloud',
              icon: const Icon(Icons.delete_outline),
              onPressed: busy
                  ? null
                  : () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Supprimer cette pièce jointe ?'),
                          content: const Text(
                            'La copie cloud sera supprimée. Le fichier original reste sur votre appareil.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Annuler'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true && mounted) {
                        await perform(() async {
                          await widget.cloud!.attachmentAction(
                            'remove',
                            widget.taskId,
                            id: item['id'] as String,
                          );
                        });
                      }
                    },
            ),
          ),
        OutlinedButton.icon(
          onPressed: busy ? null : add,
          icon: const Icon(Icons.upload_file),
          label: const Text('Ajouter une pièce jointe'),
        ),
        const Text(
          '10 Mo maximum par fichier. La copie cloud est supprimée lorsque la tâche est terminée. Le fichier original reste sur votre appareil.',
        ),
        TextButton(
          onPressed: busy ? null : load,
          child: const Text('Actualiser les fichiers'),
        ),
      ],
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      const SizedBox(height: 16),
    ],
  );
}
