import '../../../../core/constants/service_category.dart';
import '../domain/service_opportunity.dart';

const mockServiceOpportunities = <ServiceOpportunity>[
  ServiceOpportunity(
    id: 'fuga-lavaplatos',
    title: 'Reparar fuga bajo el lavaplatos',
    category: ServiceCategory.plumbing,
    postedLabel: 'Hace 5 min',
    budget: '\$80.000 – \$140.000',
    approximateLocation: 'Chapinero, Bogotá',
    description:
        'Hay una fuga constante en la conexión del lavaplatos. Se requiere revisar la tubería y cambiar las piezas que hagan falta.',
    expectedMoment: 'Hoy, en la tarde',
  ),
  ServiceOpportunity(
    id: 'ventilador-techo',
    title: 'Instalar ventilador de techo',
    category: ServiceCategory.electrical,
    postedLabel: 'Hace 18 min',
    budget: '\$65.000 – \$110.000',
    approximateLocation: 'Usaquén, Bogotá',
    description:
        'Instalación de un ventilador de techo en una habitación. El equipo ya está disponible en el domicilio.',
    expectedMoment: 'Mañana, horario flexible',
  ),
  ServiceOpportunity(
    id: 'circuito-cocina',
    title: 'Reparación de circuito en cocina',
    category: ServiceCategory.electrical,
    postedLabel: 'Hace 32 min',
    budget: '\$90.000 – \$150.000',
    approximateLocation: 'Teusaquillo, Bogotá',
    description:
        'Algunos tomacorrientes de la cocina dejaron de funcionar. Se necesita diagnóstico y reparación del circuito.',
    expectedMoment: 'Esta semana',
  ),
  ServiceOpportunity(
    id: 'pintura-habitacion',
    title: 'Pintar una habitación',
    category: ServiceCategory.painting,
    postedLabel: 'Hace 45 min',
    budget: '\$180.000 – \$280.000',
    approximateLocation: 'Suba, Bogotá',
    description:
        'Pintura interior de una habitación pequeña. La pared requiere preparación ligera antes de pintar.',
    expectedMoment: 'Fin de semana',
  ),
  ServiceOpportunity(
    id: 'cerradura-puerta',
    title: 'Cambiar cerradura de puerta principal',
    category: ServiceCategory.locksmithing,
    postedLabel: 'Hace 1 h',
    budget: '\$70.000 – \$120.000',
    approximateLocation: 'Engativá, Bogotá',
    description:
        'La cerradura está desgastada y se solicita reemplazo. La cerradura nueva puede ser cotizada por el profesional.',
    expectedMoment: 'En los próximos días',
  ),
];
