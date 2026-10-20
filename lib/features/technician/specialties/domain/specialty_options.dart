import '../../../../core/constants/service_category.dart';

const specialtyOptions = <ServiceCategory, List<String>>{
  ServiceCategory.plumbing: [
    'Reparación de fugas',
    'Instalación de grifería',
    'Destape de tuberías',
  ],
  ServiceCategory.electrical: [
    'Instalación de luminarias',
    'Reparación de circuitos',
    'Instalación de tomacorrientes',
  ],
  ServiceCategory.maintenance: [
    'Mantenimiento preventivo',
    'Reparaciones del hogar',
    'Instalación de equipos',
  ],
  ServiceCategory.locksmithing: [
    'Apertura de puertas',
    'Cambio de cerraduras',
    'Duplicado de llaves',
  ],
  ServiceCategory.painting: [
    'Pintura de interiores',
    'Pintura de fachadas',
    'Resanes y acabados',
  ],
  ServiceCategory.carpentry: [
    'Armado de muebles',
    'Reparación de puertas',
    'Muebles a medida',
  ],
};
