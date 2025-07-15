class RoleModel {
  final int id;
  final String descripcion;
  final int estatus;
  final DateTime? fechaCreacion;
  final DateTime? fechaModificacion;

  RoleModel({
    required this.id,
    required this.descripcion,
    this.estatus = 1,
    this.fechaCreacion,
    this.fechaModificacion,
  });

  factory RoleModel.fromMap(Map<String, dynamic> map) {
    return RoleModel(
      id: map['pmrl_id'],
      descripcion: map['pmrl_descripcion'],
      estatus: map['pmrl_estatus'] ?? 1,
      fechaCreacion: map['pmrl_fechacreacion'],
      fechaModificacion: map['pmrl_fechamodificacion'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pmrl_id': id,
      'pmrl_descripcion': descripcion,
      'pmrl_estatus': estatus,
      'pmrl_fechacreacion': fechaCreacion,
      'pmrl_fechamodificacion': fechaModificacion,
    };
  }
}
