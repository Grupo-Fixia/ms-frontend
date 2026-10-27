import 'package:flutter/material.dart';
import '../domain/service_application.dart';

/// Consulta autorizada del usuario actual. No sustituye historial de servicios.
class MyApplicationPricesPage extends StatefulWidget {
  const MyApplicationPricesPage({super.key, required this.loadApplications});
  final Future<List<ServiceApplication>> Function() loadApplications;
  @override
  State<MyApplicationPricesPage> createState() =>
      _MyApplicationPricesPageState();
}

class _MyApplicationPricesPageState extends State<MyApplicationPricesPage> {
  List<ServiceApplication>? _items;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.loadApplications();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) {
        setState(() {
          _items = null;
          _error = error;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis postulaciones'), actions: [
          IconButton(
              tooltip: 'Actualizar postulaciones',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh)),
        ]),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          const Text('No pudimos consultar tus postulaciones.'),
                          FilledButton(
                              onPressed: _load,
                              child: const Text('Reintentar')),
                        ])
                  : _items!.isEmpty
                      ? const Center(
                          child: Text('Todavía no tienes postulaciones.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items!.length,
                          itemBuilder: (context, index) {
                            final item = _items![index];
                            return Card(
                                child: ListTile(
                              title: Text(item.serviceRequest.category.label),
                              subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${item.serviceRequest.city} · ${item.serviceRequest.zone}'),
                                    Text(item.status.label),
                                    Text(
                                        item.proposedPrice?.label ??
                                            'Precio no informado',
                                        key: ValueKey(
                                            'application-price-${item.id}')),
                                  ]),
                            ));
                          },
                        ),
        )),
      );
}
