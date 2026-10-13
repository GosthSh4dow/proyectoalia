class CatalogoInfo {
  final int? id;
  final String? telefono;
  final String? email;
  final String? direccion;
  final String? horariosSemana;
  final String? horariosDomingo;
  final String? descripcionEmpresa;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? whatsappUrl;
  final String? tituloBanner;
  final String? subtituloBanner;
  final String? descripcionBanner;
  final String? botonBanner;
  final String? urlBotonBanner;
  final String? bannerUrl;
  final String? logoUrl;
  final bool activo;
  final List<dynamic> gruposWhatsapp;
  final List<dynamic> bannerImages;
  final List<dynamic> logoImages;

  CatalogoInfo({
    this.id,
    this.telefono,
    this.email,
    this.direccion,
    this.horariosSemana,
    this.horariosDomingo,
    this.descripcionEmpresa,
    this.facebookUrl,
    this.instagramUrl,
    this.tiktokUrl,
    this.whatsappUrl,
    this.tituloBanner,
    this.subtituloBanner,
    this.descripcionBanner,
    this.botonBanner,
    this.urlBotonBanner,
    this.bannerUrl,
    this.logoUrl,
    this.activo = true,
    this.gruposWhatsapp = const [],
    this.bannerImages = const [],
    this.logoImages = const [],
  });

  factory CatalogoInfo.fromJson(Map<String, dynamic> json) {
    return CatalogoInfo(
      id: json['id'],
      telefono: json['telefono'],
      email: json['email'],
      direccion: json['direccion'],
      horariosSemana: json['horarios_semana'],
      horariosDomingo: json['horarios_domingo'],
      descripcionEmpresa: json['descripcion_empresa'],
      facebookUrl: json['facebook_url'],
      instagramUrl: json['instagram_url'],
      tiktokUrl: json['tiktok_url'],
      whatsappUrl: json['whatsapp_url'],
      tituloBanner: json['titulo_banner'],
      subtituloBanner: json['subtitulo_banner'],
      descripcionBanner: json['descripcion_banner'],
      botonBanner: json['boton_banner'],
      urlBotonBanner: json['url_boton_banner'],
      bannerUrl: json['banner_url'],
      logoUrl: json['logo_url'],
      activo: json['activo'] ?? true,
      gruposWhatsapp: json['grupos_whatsapp'] ?? [],
      bannerImages: json['banner_images'] ?? [],
      logoImages: json['logo_images'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'horarios_semana': horariosSemana,
      'horarios_domingo': horariosDomingo,
      'descripcion_empresa': descripcionEmpresa,
      'facebook_url': facebookUrl,
      'instagram_url': instagramUrl,
      'tiktok_url': tiktokUrl,
      'whatsapp_url': whatsappUrl,
      'titulo_banner': tituloBanner,
      'subtitulo_banner': subtituloBanner,
      'descripcion_banner': descripcionBanner,
      'boton_banner': botonBanner,
      'url_boton_banner': urlBotonBanner,
      'activo': activo,
      'grupos_whatsapp': gruposWhatsapp,
      'banner_images': bannerImages,
      'logo_images': logoImages,
    };
  }
}
