import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';


import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/catalogo_model.dart';
import '../models/anuncio_model.dart';
import '../servicios/catalogo_service.dart';
import '../servicios/anuncio_service.dart';
import '../servicios/api_service.dart';
import '../providers/user_provider.dart';
import '../api.dart';
import '../utils/image_compress.dart';
import '../servicios/upload_notification_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Premium Colors
const Color kPrimaryColor = Color(0xFFC026D3);     
const Color kSecondaryColor = Color(0xFFE879F9);   
const Color kDarkPurple = Color(0xFF701A75);       
const Color kBackgroundLight = Color(0xFFFDF4FF);  
const Color kSuccessColor = Color(0xFF22C55E);

class CatalogoScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const CatalogoScreen({Key? key, this.onMenuPressed}) : super(key: key);

  @override
  _CatalogoScreenState createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> with SingleTickerProviderStateMixin {
  final CatalogoService _catalogoService = CatalogoService();
  final AnuncioService _anuncioService = AnuncioService();
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  
  CatalogoInfo? _info;
  List<Anuncio> _anuncios = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers for Settings
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _horariosSemanaController = TextEditingController();
  final TextEditingController _horariosDomingoController = TextEditingController();
  final TextEditingController _empresaDescController = TextEditingController();
  final TextEditingController _fbController = TextEditingController();
  final TextEditingController _igController = TextEditingController();
  final TextEditingController _tkController = TextEditingController();
  final TextEditingController _waController = TextEditingController();
  final TextEditingController _bannerTituloController = TextEditingController();
  final TextEditingController _bannerSubtituloController = TextEditingController();
  final TextEditingController _bannerDescController = TextEditingController();
  final TextEditingController _bannerBotonController = TextEditingController();
  final TextEditingController _bannerUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (mounted) setState(() {}); // Rebuild to update FAB
      }
    });
    // Diferir la carga de datos hasta después del primer frame para evitar
    // conflictos con el MouseTracker durante el warm-up frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final info = await _catalogoService.obtenerCatalogo();
      final anuncios = await _anuncioService.obtenerAnuncios();
      
      if (!mounted) return;
      setState(() {
        _info = info;
        _anuncios = anuncios;
        
        // Fill controllers
        _telefonoController.text = info.telefono ?? "";
        _emailController.text = info.email ?? "";
        _direccionController.text = info.direccion ?? "";
        _horariosSemanaController.text = info.horariosSemana ?? "";
        _horariosDomingoController.text = info.horariosDomingo ?? "";
        _empresaDescController.text = info.descripcionEmpresa ?? "";
        _fbController.text = info.facebookUrl ?? "";
        _igController.text = info.instagramUrl ?? "";
        _tkController.text = info.tiktokUrl ?? "";
        _waController.text = info.whatsappUrl ?? "";
        _bannerTituloController.text = info.tituloBanner ?? "";
        _bannerSubtituloController.text = info.subtituloBanner ?? "";
        _bannerDescController.text = info.descripcionBanner ?? "";
        _bannerBotonController.text = info.botonBanner ?? "";
        _bannerUrlController.text = info.urlBotonBanner ?? "";
      });
    } catch (e) {
      if (mounted) _showSnackBar("Error al cargar datos", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : kSuccessColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- SAVE SETTINGS ---
  Future<void> _saveGeneralInfo() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar("Por favor corrige los errores", isError: true);
      return;
    }
    
    setState(() => _isSaving = true);
    try {
      final data = {
        "telefono": _telefonoController.text,
        "email": _emailController.text,
        "direccion": _direccionController.text,
        "horarios_semana": _horariosSemanaController.text,
        "horarios_domingo": _horariosDomingoController.text,
        "descripcion_empresa": _empresaDescController.text,
        "facebook_url": _fbController.text,
        "instagram_url": _igController.text,
        "tiktok_url": _tkController.text,
        "whatsapp_url": _waController.text,
        "titulo_banner": _bannerTituloController.text,
        "subtitulo_banner": _bannerSubtituloController.text,
        "descripcion_banner": _bannerDescController.text,
        "boton_banner": _bannerBotonController.text,
        "url_boton_banner": _bannerUrlController.text,
        "grupos_whatsapp": jsonEncode(_info?.gruposWhatsapp ?? []), // Stringify for backend
      };
      
      if (_info?.id == null) {
        final newInfo = await _catalogoService.crearCatalogo(data);
        setState(() => _info = newInfo);
        _showSnackBar("Catálogo creado y guardado");
      } else {
        await _catalogoService.actualizarCatalogo(_info!.id!, data);
        _showSnackBar("Configuración guardada");
      }
      _loadData();
    } catch (e) {
      _showSnackBar("Error al guardar: $e", isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // --- IMAGE UPLOAD ---
  Future<void> _pickAndUploadImage(String tipo) async {
    if (_info?.id == null) {
      _showSnackBar("Primero debes guardar la información general", isError: true);
      return;
    }
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isSaving = true);

    final notifService = UploadNotificationService();
    try {
      // Notificación: Comprimiendo
      await notifService.showCompressingNotification(
        message: "Comprimiendo imagen a WebP...",
      );

      // Comprimir imagen a WebP
      final compressed = await compressImage(File(image.path));
      final fileToUpload = compressed ?? File(image.path);

      // Notificación: Subiendo
      ApiService().setUploadTimeout();
      await notifService.showUploadingNotification(
        message: "Subiendo imagen...",
      );

      await _catalogoService.subirImagen(
        _info!.id!,
        tipo,
        fileToUpload,
        onProgress: (sent, total) {
          if (total > 0) {
            final percent = (sent / total * 100).toInt();
            notifService.showUploadingNotification(
              progress: percent,
              message: "Subiendo... $percent%",
            );
          }
        },
      );

      await notifService.showSuccessNotification(message: "¡Imagen subida!");
      await notifService.cancelAll();
      ApiService().resetTimeout();
      _showSnackBar("Imagen subida");
      _loadData();
    } catch (e) {
      ApiService().resetTimeout();
      await notifService.showErrorNotification(message: "Error al subir imagen");
      _showSnackBar("Error al subir imagen: $e", isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteImage(String tipo, String imagenId) async {
    if (_info?.id == null) return;
    setState(() => _isSaving = true);
    try {
      await _catalogoService.eliminarImagen(_info!.id!, tipo, imagenId);
      _showSnackBar("Imagen eliminada");
      _loadData();
    } catch (e) {
      _showSnackBar("Error al eliminar", isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // --- WHATSAPP GROUPS ---
  void _addWhatsappGroup() {
    setState(() {
      final updatedGroups = List.from(_info?.gruposWhatsapp ?? []);
      updatedGroups.add({
        "name": "Nuevo Grupo",
        "link": "",
        "members": "0+",
        "status": "activo"
      });
      _info = CatalogoInfo.fromJson({
        ..._info!.toJson(),
        'grupos_whatsapp': updatedGroups
      });
    });
  }

  void _removeWhatsappGroup(int index) {
    setState(() {
      final updatedGroups = List.from(_info?.gruposWhatsapp ?? []);
      updatedGroups.removeAt(index);
      _info = CatalogoInfo.fromJson({
        ..._info!.toJson(),
        'grupos_whatsapp': updatedGroups
      });
    });
  }

  // --- ANNOUNCEMENTS ACTIONS ---
  Future<void> _deleteAnuncio(int id) async {
    setState(() => _isSaving = true);
    try {
      await _anuncioService.eliminarAnuncio(id);
      _showSnackBar("Anuncio eliminado");
      _loadData();
    } catch (e) {
      _showSnackBar("Error al eliminar anuncio", isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleAnuncioStatus(Anuncio a, bool status) async {
    final userId = Provider.of<UserProvider>(context, listen: false).userId;
    if (userId == null) return;
    
    // Usar addPostFrameCallback para garantizar que no ocurra durante un frame de puntero
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isSaving = true);
    });
    try {
      final updated = a.copyWith(activo: status);
      await _anuncioService.actualizarAnuncio(a.id!, updated, null, creatorId: userId);
      _loadData();
    } catch (e) {
      _showSnackBar("Error al cambiar estado", isError: true);
    } finally {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isSaving = false);
        });
      }
    }
  }

  void _showAnuncioModal({Anuncio? anuncio}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AnuncioFormModal(
        anuncio: anuncio,
        onSave: (newAnuncio, imageFile) async {
          final userId = Provider.of<UserProvider>(context, listen: false).userId;
          if (userId == null) {
            _showSnackBar("Sesión no válida", isError: true);
            return;
          }
          setState(() => _isSaving = true);
          try {
            if (anuncio != null) {
              await _anuncioService.actualizarAnuncio(anuncio.id!, newAnuncio, imageFile, creatorId: userId);
              _showSnackBar("Anuncio actualizado");
            } else {
              await _anuncioService.crearAnuncio(newAnuncio, imageFile, creatorId: userId);
              _showSnackBar("Anuncio creado");
            }
            _loadData();
          } catch (e) {
            _showSnackBar("Error al guardar anuncio: $e", isError: true);
          } finally {
            if (mounted) {
              Future.microtask(() => setState(() => _isSaving = false));
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    return Scaffold(
      backgroundColor: kBackgroundLight,
      body: _isLoading 
        ? Center(child: SpinKitFadingCircle(color: kPrimaryColor, size: 50.0))
        : Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSettingsTab(),
                      _buildAnunciosTab(),
                      _buildComunidadesTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE879F9), Color(0xFFC026D3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Decorative Circles matching Ventas
            Positioned(
              top: -40.h,
              right: -40.w,
              child: CircleAvatar(radius: 80.r, backgroundColor: Colors.white.withOpacity(0.1)),
            ),
            Positioned(
              bottom: -20.h,
              left: -20.w,
              child: CircleAvatar(radius: 60.r, backgroundColor: Colors.white.withOpacity(0.1)),
            ),
            
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 5.h),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LineIcons.bars, color: Colors.white, size: 20),
                        ),
                        onPressed: widget.onMenuPressed,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gestión Catálogo',
                              style: GoogleFonts.poppins(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'PÁGINA Y COMUNIDAD',
                              style: GoogleFonts.poppins(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.8),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 4,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.sp),
                  unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.normal),
                  tabs: const [
                    Tab(text: "AJUSTES"),
                    Tab(text: "ANUNCIOS"),
                    Tab(text: "COMUNIDADES"),
                  ],
                ),
                SizedBox(height: 10.h),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    if (_isLoading) return const SizedBox();
    
    return FloatingActionButton.extended(
      onPressed: _isSaving ? null : () {
        if (_tabController.index == 0) {
          _saveGeneralInfo();
        } else if (_tabController.index == 1) {
          _showAnuncioModal();
        } else {
          _saveGeneralInfo(); 
        }
      },
      backgroundColor: _isSaving ? Colors.grey : kPrimaryColor,
      label: _isSaving 
        ? const SpinKitThreeBounce(color: Colors.white, size: 20)
        : Text(
            _tabController.index == 1 ? "NUEVO ANUNCIO" : "GUARDAR TODO",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
      icon: _isSaving ? null : Icon(_tabController.index == 1 ? LineIcons.plus : LineIcons.checkCircle),
    );
  }

  // --- TABS ---

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildSectionTitle("Información General", LineIcons.infoCircle),
          _buildContainerCard(
            child: Column(
              children: [
                _buildTextField(_telefonoController, "Teléfono", LineIcons.phone),
                _buildTextField(_emailController, "Email", LineIcons.envelope),
                _buildTextField(_direccionController, "Dirección", LineIcons.mapMarker),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          _buildSectionTitle("Horarios y Empresa", LineIcons.clock),
          _buildContainerCard(
            child: Column(
              children: [
                _buildTextField(_horariosSemanaController, "Semana", LineIcons.clock),
                _buildTextField(_horariosDomingoController, "Domingo", LineIcons.clock),
                _buildTextField(_empresaDescController, "Sobre la empresa", LineIcons.comment, maxLines: 3),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          _buildSectionTitle("Redes Sociales", LineIcons.share),
          _buildContainerCard(
            child: Column(
              children: [
                _buildTextField(_fbController, "Facebook", LineIcons.facebook),
                _buildTextField(_igController, "Instagram", LineIcons.instagram),
                _buildTextField(_tkController, "TikTok", LineIcons.video),
                _buildTextField(_waController, "WhatsApp", LineIcons.whatSApp),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          _buildSectionTitle("Banner Principal", LineIcons.ad),
          _buildContainerCard(
            child: Column(
              children: [
                _buildTextField(_bannerTituloController, "Título", LineIcons.heading),
                _buildTextField(_bannerSubtituloController, "Subtítulo", LineIcons.font),
                _buildTextField(_bannerDescController, "Descripción", LineIcons.alignLeft, maxLines: 2),
                _buildTextField(_bannerBotonController, "Texto Botón", LineIcons.mousePointer),
                _buildTextField(_bannerUrlController, "URL Botón", LineIcons.link),
                if (_info?.bannerUrl != null) ...[
                  SizedBox(height: 12.h),
                  _buildPrimaryImagePreview("banner", _info!.bannerUrl!),
                ],
              ],
            ),
          ),
          SizedBox(height: 20.h),
          _buildSectionTitle("Logotipo Principal", LineIcons.certificate),
          _buildContainerCard(
            child: Column(
              children: [
                if (_info?.logoUrl != null) 
                  _buildPrimaryImagePreview("logo", _info!.logoUrl!)
                else
                  Text("No hay logotipo principal configurado", style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.grey)),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          _buildSectionTitle("Galería de Banners", LineIcons.images),
          _buildImageGallery("banner", _info?.bannerImages ?? []),
          SizedBox(height: 20.h),
          _buildSectionTitle("Galería de Logotipos", LineIcons.certificate),
          _buildImageGallery("logo", _info?.logoImages ?? []),
          SizedBox(height: 100.h),
        ],
      ),
    );
  }

  Widget _buildAnunciosTab() {
    if (_anuncios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LineIcons.bullhorn, size: 60, color: Colors.grey.shade300),
            SizedBox(height: 16.h),
            Text("No hay anuncios publicados", style: GoogleFonts.poppins(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      physics: const BouncingScrollPhysics(),
      itemCount: _anuncios.length,
      itemBuilder: (context, index) {
        final a = _anuncios[index];
        return _buildAnuncioCard(a);
      },
    );
  }

  Widget _buildComunidadesTab() {
    final groups = _info?.gruposWhatsapp ?? [];
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildSectionTitle("Grupos de WhatsApp", LineIcons.whatSApp),
          ...List.generate(groups.length, (index) {
            final g = groups[index];
            return _buildGroupEditCard(index, g);
          }),
          SizedBox(height: 20.h),
          _buildAddGroupButton(),
          SizedBox(height: 100.h),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryColor, size: 20.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(fontSize: 16.sp, fontWeight: FontWeight.bold, color: kDarkPurple),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContainerCard({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w500, color: kDarkPurple),
        validator: (value) {
          if (label == "Teléfono" || label == "Email" || label == "Dirección") {
            if (value == null || value.isEmpty) return "Requerido";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kPrimaryColor.withOpacity(0.8), size: 18.sp),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Widget _buildImageGallery(String tipo, List<dynamic> images) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.w,
        childAspectRatio: 1.2,
      ),
      itemCount: images.length + 1,
      itemBuilder: (context, index) {
        if (index == images.length) return _buildAddImageButton(tipo);
        final img = images[index];
        return _buildImageItem(tipo, img);
      },
    );
  }

  Widget _buildAddImageButton(String tipo) {
    return InkWell(
      onTap: () => _pickAndUploadImage(tipo),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: kPrimaryColor.withOpacity(0.2), width: 1.5, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LineIcons.plus, color: kPrimaryColor, size: 24.sp),
            Text("Añadir", style: GoogleFonts.poppins(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 12.sp)),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryImagePreview(String tipo, String url) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15.r),
          child: CachedNetworkImage(
            imageUrl: getImageUrl(url),
            height: 120.h, width: double.infinity, fit: BoxFit.cover,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => Container(
              height: 120.h, color: Colors.grey.shade100,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
        Positioned(
          top: 8, right: 8,
          child: GestureDetector(
            onTap: () => _deletePrimaryImage(tipo),
            child: CircleAvatar(
              radius: 14.r,
              backgroundColor: Colors.white,
              child: Icon(Icons.delete_outline, size: 18.sp, color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deletePrimaryImage(String tipo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Imagen"),
        content: Text("¿Estás seguro de que deseas eliminar este ${tipo == 'banner' ? 'banner' : 'logotipo'} principal?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("ELIMINAR", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _catalogoService.eliminarImagenPrincipal(_info!.id!, tipo);
        _loadData(); // Recargar datos
        _showSnackBar("Imagen eliminada correctamente");
      } catch (e) {
        _showSnackBar("Error al eliminar imagen: $e", isError: true);
      }
    }
  }

  Widget _buildImageItem(String tipo, dynamic img) {
    final url = img['url'] ?? "";
    final id = img['id'].toString();
    final fullUrl = getImageUrl(url);

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: CachedNetworkImage(
            imageUrl: fullUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorWidget: (context, url, error) => const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.grey),
                Text("Error", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            )),
          ),
        ),
        Positioned(
          top: 5, right: 5,
          child: GestureDetector(
            onTap: () => _deleteImage(tipo, id),
            child: CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Icon(Icons.close, size: 14, color: Colors.red.shade400)),
          ),
        ),
      ],
    );
  }

  Widget _buildAnuncioCard(Anuncio a) {
    final df = DateFormat('dd/MM/yyyy');
    final color = a.tipo == 'promo' ? Colors.pink : a.tipo == 'alerta' ? Colors.red : Colors.blue;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a.imagen != null)
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              child: CachedNetworkImage(
                imageUrl: getImageUrl(a.imagen),
                height: 120.h, width: double.infinity, fit: BoxFit.cover,
                placeholder: (context, url) => const Center(child: SpinKitPulse(color: kPrimaryColor)),
                errorWidget: (context, url, error) => Container(
                  height: 120.h, color: Colors.grey.shade100,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(a.tipo.toUpperCase(), style: GoogleFonts.poppins(color: color, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    if (a.bloqueante)
                      Icon(Icons.lock_clock, color: Colors.orange, size: 16.sp),
                    SizedBox(width: 8.w),
                    // Custom toggle en lugar de Switch para evitar errores de MouseRegion en desktop
                    GestureDetector(
                      onTap: () => _toggleAnuncioStatus(a, !a.activo),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 24,
                        decoration: BoxDecoration(
                          color: a.activo ? kPrimaryColor : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: a.activo ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(a.titulo, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15.sp)),
                Text(a.mensaje, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.grey.shade600)),
                Divider(height: 24.h),
                Row(
                  children: [
                    Icon(LineIcons.clock, size: 14, color: Colors.grey),
                    SizedBox(width: 4.w),
                    Text("${df.format(a.fechaInicio)} - ${df.format(a.fechaExpiracion)}", style: GoogleFonts.poppins(fontSize: 11.sp, color: Colors.grey)),
                    const Spacer(),
                    IconButton(icon: Icon(LineIcons.edit, color: kPrimaryColor, size: 20.sp), onPressed: () => _showAnuncioModal(anuncio: a)),
                    IconButton(icon: Icon(LineIcons.trash, color: Colors.red.shade400, size: 20.sp), onPressed: () => _deleteAnuncio(a.id!)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupEditCard(int index, dynamic group) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15.r), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: kSuccessColor.withOpacity(0.1), child: const Icon(LineIcons.whatSApp, color: kSuccessColor)),
              SizedBox(width: 12.w),
              Expanded(
                child: TextFormField(
                  initialValue: group['name'],
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(border: InputBorder.none, hintText: "Nombre del grupo"),
                  onChanged: (v) => _info!.gruposWhatsapp[index]['name'] = v,
                ),
              ),
              IconButton(icon: const Icon(LineIcons.trash, color: Colors.red), onPressed: () => _removeWhatsappGroup(index)),
            ],
          ),
          TextFormField(
            initialValue: group['link'],
            decoration: InputDecoration(labelText: "Enlace de invitación", prefixIcon: const Icon(LineIcons.link, size: 16), labelStyle: TextStyle(fontSize: 12.sp)),
            onChanged: (v) => _info!.gruposWhatsapp[index]['link'] = v,
          ),
        ],
      ),
    );
  }

  Widget _buildAddGroupButton() {
    return InkWell(
      onTap: _addWhatsappGroup,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(color: kSuccessColor.withOpacity(0.1), borderRadius: BorderRadius.circular(15.r), border: Border.all(color: kSuccessColor.withOpacity(0.3))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LineIcons.plus, color: kSuccessColor),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                "AGREGAR GRUPO",
                style: GoogleFonts.poppins(color: kSuccessColor, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MODAL FORM FOR ANNOUNCEMENTS ---

class AnuncioFormModal extends StatefulWidget {
  final Anuncio? anuncio;
  final Function(Anuncio, File?) onSave;

  const AnuncioFormModal({Key? key, this.anuncio, required this.onSave}) : super(key: key);

  @override
  _AnuncioFormModalState createState() => _AnuncioFormModalState();
}

class _AnuncioFormModalState extends State<AnuncioFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tituloController;
  late TextEditingController _mensajeController;
  late String _tipo;
  late DateTime _fechaInicio;
  late DateTime _fechaExpiracion;
  late bool _activo;
  late bool _bloqueante;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.anuncio?.titulo ?? "");
    _mensajeController = TextEditingController(text: widget.anuncio?.mensaje ?? "");
    _tipo = widget.anuncio?.tipo ?? "info";
    _fechaInicio = widget.anuncio?.fechaInicio ?? DateTime.now();
    _fechaExpiracion = widget.anuncio?.fechaExpiracion ?? DateTime.now().add(const Duration(days: 7));
    _activo = widget.anuncio?.activo ?? true;
    _bloqueante = widget.anuncio?.bloqueante ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(widget.anuncio == null ? "Nuevo Anuncio" : "Editar Anuncio", 
                      style: GoogleFonts.poppins(fontSize: 20.sp, fontWeight: FontWeight.bold, color: kDarkPurple)),
                    const Spacer(),
                    IconButton(icon: Icon(LineIcons.times, size: 24.sp), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                Divider(height: 30.h),
                _buildTypeSelector(),
                SizedBox(height: 20.h),
                _buildTextField(_tituloController, "Título del anuncio", LineIcons.heading),
                _buildTextField(_mensajeController, "Mensaje / Cuerpo", LineIcons.bullhorn, maxLines: 4),
                SizedBox(height: 10.h),
                _buildImagePicker(),
                SizedBox(height: 20.h),
                _buildDateSelector("Inicia", _fechaInicio, (d) => setState(() => _fechaInicio = d)),
                _buildDateSelector("Expira", _fechaExpiracion, (d) => setState(() => _fechaExpiracion = d)),
                SizedBox(height: 10.h),
                SwitchListTile(
                  title: Text("Bloqueante", style: GoogleFonts.poppins(fontSize: 14.sp)),
                  subtitle: Text("El usuario debe leerlo para continuar", style: TextStyle(fontSize: 11.sp)),
                  value: _bloqueante,
                  onChanged: (v) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _bloqueante = v);
                    });
                  },
                  activeColor: kPrimaryColor,
                ),
                SwitchListTile(
                  title: Text("Activo", style: GoogleFonts.poppins(fontSize: 14.sp)),
                  value: _activo,
                  onChanged: (v) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _activo = v);
                    });
                  },
                  activeColor: kPrimaryColor,
                ),


                SizedBox(height: 30.h),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(child: _typeChip("info", LineIcons.info, Colors.blue)),
        SizedBox(width: 8.w),
        Expanded(child: _typeChip("promo", LineIcons.tag, Colors.pink)),
        SizedBox(width: 8.w),
        Expanded(child: _typeChip("alerta", LineIcons.exclamationTriangle, Colors.red)),
      ],
    );
  }

  Widget _typeChip(String type, IconData icon, Color color) {
    bool isSel = _tipo == type;
    return GestureDetector(
      onTap: () => setState(() => _tipo = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSel ? color : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSel ? Colors.transparent : color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: isSel ? Colors.white : color),
            SizedBox(width: 5.w),
            Flexible(
              child: Text(
                type.toUpperCase(),
                style: GoogleFonts.poppins(color: isSel ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 9.sp),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon, color: kPrimaryColor),
          filled: true, fillColor: kBackgroundLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.r), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: () async {
        final img = await _picker.pickImage(source: ImageSource.gallery);
        if (img != null) setState(() => _imageFile = File(img.path));
      },
      child: Container(
        height: 120.h, width: double.infinity,
        decoration: BoxDecoration(color: kBackgroundLight, borderRadius: BorderRadius.circular(15.r), border: Border.all(color: kPrimaryColor.withOpacity(0.1))),
        child: _imageFile != null 
          ? ClipRRect(borderRadius: BorderRadius.circular(15.r), child: Image.file(_imageFile!, fit: BoxFit.cover))
          : widget.anuncio?.imagen != null
            ? ClipRRect(borderRadius: BorderRadius.circular(15.r), child: CachedNetworkImage(
                imageUrl: getImageUrl(widget.anuncio!.imagen),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image),
              ))
            : const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(LineIcons.image, color: kPrimaryColor), Text("Seleccionar Imagen")])),
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime date, Function(DateTime) onPick) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    return ListTile(
      title: Text(label, style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.bold)),
      subtitle: Text(df.format(date)),
      trailing: const Icon(LineIcons.calendar, color: kPrimaryColor),
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (d != null) {
          final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(date));
          if (t != null) onPick(DateTime(d.year, d.month, d.day, t.hour, t.minute));
        }
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r))),
        onPressed: () {
          final a = Anuncio(
            id: widget.anuncio?.id,
            titulo: _tituloController.text,
            mensaje: _mensajeController.text,
            tipo: _tipo,
            fechaInicio: _fechaInicio,
            fechaExpiracion: _fechaExpiracion,
            activo: _activo,
            bloqueante: _bloqueante,
          );
          // Diferir el pop y el onSave para evitar errores de MouseTracker o Layout
          Future.microtask(() {
            if (context.mounted) Navigator.pop(context);
            widget.onSave(a, _imageFile);
          });
        },
        child: Text("GUARDAR ANUNCIO", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16.sp, color: Colors.white)),
      ),
    );
  }
}
