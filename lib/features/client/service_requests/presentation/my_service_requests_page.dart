import 'package:flutter/material.dart';

import '../domain/service_request.dart';

class MyServiceRequestsPage extends StatefulWidget {
  const MyServiceRequestsPage(
      {super.key, required this.load, required this.get});

  final Future<List<ServiceRequest>> Function() load;
  final Future<ServiceRequest> Function(String id) get;

  @override
  State<MyServiceRequestsPage> createState() => _MyServiceRequestsPageState();
}

class _MyServiceRequestsPageState extends State<MyServiceRequestsPage> {
  late Future<List<ServiceRequest>> _requests = widget.load();
  bool _opening = false;

  Future<void> _open(ServiceRequest request) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final saved = await widget.get(request.id);
      if (!mounted) return;
      setState(() => _opening = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(saved.category.label),
          content: Text('${saved.description}\n\nPresupuesto orientativo\n'
              '${saved.budget?.label ?? 'Presupuesto no informado'}'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'))
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis solicitudes'), actions: [
          IconButton(
              tooltip: 'Actualizar solicitudes',
              onPressed: () {
                setState(() {
                  _requests = widget.load();
                });
              },
              icon: const Icon(Icons.refresh)),
        ]),
        body: FutureBuilder<List<ServiceRequest>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('${snapshot.error}'));
            }
            final requests = snapshot.data!;
            if (requests.isEmpty) {
              return const Center(
                  child: Text('Todavía no tienes solicitudes.'));
            }
            return ListView(children: [
              if (_opening) const LinearProgressIndicator(),
              for (final request in requests)
                ListTile(
                  title: Text(request.description),
                  subtitle: Text(
                      'Presupuesto orientativo: ${request.budget?.label ?? 'Presupuesto no informado'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _opening ? null : () => _open(request),
                ),
            ]);
          },
        ),
      );
}
