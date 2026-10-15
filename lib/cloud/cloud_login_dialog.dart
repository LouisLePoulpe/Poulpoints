import 'package:flutter/material.dart';

/// Values returned by the login dialog. No password is saved by this widget.
class CloudLoginDetails {
  const CloudLoginDetails({
    required this.url,
    required this.publicKey,
    required this.email,
    required this.password,
  });

  final String url;
  final String publicKey;
  final String email;
  final String password;
}

/// Keep the TextEditingControllers alive for the entire lifetime of the
/// dialog's route, including the pop / closing animation.
///
/// `await showDialog` completes at Navigator.pop, which can happen *before*
/// the closing animation removes all TextFields from the widget tree. Owning
/// the controllers in this State avoids disposing them prematurely.
class CloudLoginDialog extends StatefulWidget {
  const CloudLoginDialog({
    super.key,
    this.initialUrl = '',
    this.initialPublicKey = '',
  });

  final String initialUrl;
  final String initialPublicKey;

  @override
  State<CloudLoginDialog> createState() => _CloudLoginDialogState();
}

class _CloudLoginDialogState extends State<CloudLoginDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _url;
  late final TextEditingController _publicKey;
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.initialUrl);
    _publicKey = TextEditingController(text: widget.initialPublicKey);
  }

  @override
  void dispose() {
    _url.dispose();
    _publicKey.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      CloudLoginDetails(
        url: _url.text.trim(),
        publicKey: _publicKey.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Champ obligatoire' : null;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Poulapp Cloud — connexion'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Supabase Cloud réservé aux comptes invités, ou '
                'votre propre instance Supabase. La clé publique n’est pas '
                'une clé service_role. Aucun mot de passe n’est conservé.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL HTTPS Supabase',
                ),
                validator: (value) {
                  if (_required(value) != null) return 'Champ obligatoire';
                  final uri = Uri.tryParse(value!.trim());
                  if (uri == null ||
                      uri.scheme != 'https' ||
                      uri.host.isEmpty) {
                    return 'Adresse HTTPS valide requise';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _publicKey,
                decoration: const InputDecoration(
                  labelText: 'Clé publishable / anon (publique)',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail Poulapp'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe Poulapp',
                ),
                validator: _required,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Annuler'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Se connecter')),
    ],
  );
}
