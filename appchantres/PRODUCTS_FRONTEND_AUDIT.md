# PRODUCTS FRONTEND AUDIT - appchantres

## Scope
Optimización exclusiva del módulo Productos en `channels/appchantres`. Sin cambios al backend.

---

## ARCHIVOS ANALIZADOS

| Archivo | Líneas | Rol |
|---|---|---|
| `paginas/productos_screen.dart` | 1410 | Screen principal, CRUD, filtros, paginación |
| `widgets/product/product_form_modal.dart` | 2637 | Formulario create/edit, 3 pasos, draft, validación |
| `widgets/product/product_list_item_card.dart` | 320 | Card de producto en grid |
| `widgets/product/product_skeleton_card.dart` | 83 | Skeleton loading |
| `servicios/producto_service.dart` | 84 | API calls (obtener, buscar, verificar código) |
| `servicios/producto_maestro_service.dart` | 37 | API productos maestros (2 endpoints) |
| `servicios/producto_codigo_service.dart` | 56 | API códigos alternativos (3 endpoints) |
| `servicios/pending_upload_service.dart` | 223 | Cola de reintento offline |
| `servicios/upload_queue.dart` | 118 | Upload genérico con retry |
| `servicios/upload_notification_service.dart` | 216 | Notificaciones locales de progreso |
| `providers/local_connection_provider.dart` | 279 | Conexión Socket local + HTTP fallback |
| `models/producto.dart` | — | Modelo Producto |
| `models/producto_maestro.dart` | — | Modelo ProductoMaestro |
| `models/producto_codigo.dart` | — | Modelo ProductoCodigo |
| `models/producto_variante.dart` | — | Modelo ProductoVariante |
| `models/product_form_data.dart` | 166 | FormData model (BranchDistribution) |
| `models/pending_upload.dart` | — | Modelo PendingUpload |
| `models/upload_state.dart` | 72 | UploadPhase state machine |
| `utils/image_compress.dart` | 122 | Compresión JPEG nativa + fallback |

---

## ISSUES ENCONTRADOS

### CRÍTICOS (C)

#### C1: _fetchAllData() se llama después de cada CRUD — Llamada GET innecesaria
- **Archivo**: `productos_screen.dart:1139,1194,1275`
- **Problema**: Después de crear/editar/eliminar/trasladar un producto, se llama `_fetchAllData()` que hace GET a `/productos`, `/categorias`, `/proveedores`, `/sucursales` — 4 llamadas HTTP innecesarias.
- **Evidencia**:
  ```dart
  // Línea 1139 - después de guardar
  await _fetchAllData();
  
  // Línea 1194 - después de eliminar
  await _fetchAllData();
  
  // Línea 1275 - después de trasladar
  _fetchAllData();
  ```
- **Impacto**: Latencia visible al usuario después de cada operación. Se cargan categorías, proveedores y sucursales que no cambiaron.
- **Fix**: Usar la respuesta del POST/PUT/DELETE para actualizar `_allProductos` localmente. Solo recargar si la operación falla.

#### C2: _loadDraft() se llama dos veces consecutivas
- **Archivo**: `product_form_modal.dart:215-216`
- **Problema**: `_initializeApp()` llama `_loadDraft()` dos veces:
  ```dart
  await _loadDraft();
  await _loadDraft(); // Duplicado exacto
  ```
- **Impacto**: Doble lectura de SharedPreferences innecesaria en cada apertura del form.

#### C3: UploadService y PendingUploadService hacen lo mismo — Duplicación
- **Archivos**: `upload_queue.dart` vs `pending_upload_service.dart`
- **Problema**: Ambos servicios manejan upload con retry exponencial. `UploadService` (upload_queue.dart) es una clase estática que hace lo mismo que `PendingUploadService.enviar()`.
- **Evidencia**: `PendingUploadService.enviar()` en línea 145-209 y `UploadService.uploadProduct()` en línea 18-74 hacen exactamente lo mismo.
- **Impacto**: Confusión sobre cuál usar, código duplicado.

#### C4: _filterProducts() llama setState 2 veces por cada keystroke
- **Archivo**: `productos_screen.dart:209-309`
- **Problema**: `_onSearchChanged()` → `_filterProducts()` que hace:
  1. `setState(() => _loading = true)` — primer rebuild
  2. Procesamiento sincrónico (filter + grouping)
  3. `setState(() => _loading = false)` — segundo rebuild
- **Impacto**: 2 rebuilds por cada tecla, sin debounce.

---

### ALTOS (H)

#### H1: Búsqueda sin debounce — cada tecla filtra inmediatamente
- **Archivo**: `productos_screen.dart:205-207`
- **Problema**: `_searchController.addListener(_onSearchChanged)` sin debounce.
- **Evidencia**:
  ```dart
  void _onSearchChanged() {
    _filterProducts(); // Sin debounce, cada tecla activa filtrado completo
  }
  ```
- **Impacto**: Con 1000+ productos, cada tecla hace grouping O(n) + filter O(n).

#### H2: _printEtiqueta() solo muestra SnackBar — no imprime
- **Archivo**: `productos_screen.dart:1201-1209`
- **Problema**: `_printEtiqueta()` solo muestra un snackBar. No hay lógica de impresión.
- **Evidencia**:
  ```dart
  void _printEtiqueta(Map<String, dynamic> producto) {
    // ...validación...
    _showSnackBar('Imprimiendo etiqueta para $codigo', isSuccess: true);
    // Fin de función - no imprime nada
  }
  ```
- **Impacto**: Función de UI rota.

#### H3: TransferProductDialog._trasladar() es mock — no hace nada
- **Archivo**: `productos_screen.dart:1343-1366`
- **Problema**: `_trasladar()` tiene API call comentado y usa `Future.delayed` fake.
- **Evidencia**:
  ```dart
  /*
  await widget.dio.post('$BASE_URL/traslados', data: { ... });
  */
  await Future.delayed(Duration(seconds: 1));
  widget.onSuccess();
  ```
- **Impacto**: Traslado no funciona realmente.

#### H4: print() statements en producción — datos sensibles en logs
- **Archivo**: `productos_screen.dart:213,220,306,572,604,707-713` y múltiples en otros archivos
- **Problema**: ~15+ `print()` en producción con datos sensibles (IDs, nombres, estados).
- **Impacto**: Logs expuestos en release, potencial leak de información.

#### H5: ProductFormData model existe pero NO se usa
- **Archivo**: `models/product_form_data.dart`
- **Problema**: `ProductFormData` tiene `fromJson`, `toJson`, `copy()` pero nunca se importa en `productos_screen.dart` ni `product_form_modal.dart`. El form usa raw `Map<String, dynamic>`.
- **Impacto**: Modelo muerto, código confuso.

#### H6: ProductoMaestroService se importa pero no se usa en Products flow
- **Archivo**: `servicios/producto_maestro_service.dart`
- **Problema**: No hay referencia a `ProductoMaestroService` en `productos_screen.dart` ni `product_form_modal.dart`.
- **Evidencia**: grep en screen/form no encuentra uso.
- **Impacto**: Código muerto.

#### H7: _buildBarcodeSection() es función global muerta
- **Archivo**: `productos_screen.dart:1286-1308`
- **Problema**: `_buildBarcodeSection()` está fuera de la clase `_ProductosScreenState` y no se llama desde ningún widget.
- **Impacto**: Código muerto.

---

### MEDIOS (M)

#### M1: _generateCode() usa timestamp — colisiones posibles
- **Archivo**: `product_form_modal.dart:223-228`
- **Problema**: Genera código con `timestamp.toString().substring(...)` — puede colisionar si dos usuarios crean al mismo tiempo.
- **Fix**: Usar UUID o generar con sufijo aleatorio.

#### M2: image_compress.dart — comment dice "WebP" pero comprime a JPEG
- **Archivo**: `utils/image_compress.dart:17-18`
- **Problema**: Comentario dice "Comprime una imagen a JPEG" pero línea 18 dice "El backend solo acepta imágenes JPEG (.jpg)". Sin embargo, notificaciones en `productos_screen.dart:1052` dicen "Comprimiendo a WebP".
- **Impacto**: Confusión sobre formato real.

#### M3: _initializeApp() llama SharedPreferences sin await
- **Archivo**: `product_form_modal.dart:212`
- **Problema**: `_prefs = await SharedPreferences.getInstance();` está bien, pero luego `_loadDraft()` lee `_prefs` que podría no estar inicializado si `_initializeApp()` es async pero se llama desde `initState()` sin等待.
- **Evidencia**: `initState()` llama `_initializeApp()` que es async — el `await` dentro de `_initializeApp()` no bloquea `initState()`.
- **Impacto**: Race condition potencial al cargar draft.

#### M4: Exceso de archivos temporales de compresión
- **Archivo**: `image_compress.dart:34`
- **Problema**: Archivos comprimidos se guardan en directorio temporal con prefijo `compressed_` pero nunca se limpian.
- **Impacto**: Acumulación de archivos en `/tmp`.

#### M5: _fetchProductos() hace parse manual de response.data
- **Archivo**: `productos_screen.dart:141-161`
- **Problema**: `_allProductos = response.data` asigna directamente el response sin parsear a modelos. Depende de `dynamic` para todo.
- **Impacto**: Sin type safety, errores en runtime.

#### M6: Three different upload services with overlapping responsibilities
- **Archivos**: `upload_queue.dart`, `pending_upload_service.dart`, `producto_service.dart`
- **Problema**: Tres servicios con capacidades de upload superpuestas.

#### M7: _deleteProduct() hace DELETE directo con Dio — no usa ProductoService
- **Archivo**: `productos_screen.dart:1192`
- **Problema**: `_dio.delete('$BASE_URL/productos/$id')` en vez de usar `ProductoService`.
- **Impacto**: Inconsistencia — algunos usan servicio, otros no.

#### M8: _showProductModal() pasa categorías/proveedores como List mutable
- **Archivo**: `productos_screen.dart:1031-1033`
- **Problema**: Pasa `_categorias`, `_proveedores`, `_sucursales` como listas mutables al form. El form puede modificarlas (`widget.categorias.clear()` en línea 842).
- **Impacto**: Side effects en el estado del screen padre.

#### M9: Consumer<UserProvider> en _buildBranchSelectorWidget() reconstruye todo el widget
- **Archivo**: `productos_screen.dart:569`
- **Problema**: `Consumer<UserProvider>` envuelve `_buildBranchSelectorWidget()` pero el rebuild incluye print debug innecesario.
- **Impacto**: Performance overhead mínimo + print en producción.

#### M10: Syncfusion barcodes import innecesario en productos_screen.dart
- **Archivo**: `productos_screen.dart:16`
- **Problema**: `import 'package:syncfusion_flutter_barcodes/barcodes.dart'` se importa en productos_screen.dart pero solo se usa en `_buildBarcodeSection()` que es código muerto.
- **Impacto**: Import innecesario, tăng包大小.

#### M11: WillPopScope deprecated pattern
- **Archivo**: `product_form_modal.dart:352`
- **Problema**: `WillPopScope` está deprecated en Flutter 3.12+. Usar `PopScope` en vez.
- **Impacto**: Deprecation warning.

#### M12: _saveDraft() guarda fecha_caducidad como ISO pero _loadDraft() parsea sin try-catch
- **Archivo**: `product_form_modal.dart:282-284`
- **Problema**: `_loadDraft()` hace `DateTime.parse(draft['fecha_caducidad'])` sin verificar si es null o string vacío.
- **Impacto**: Crash si draft tiene fecha_caducidad vacía.

---

### BAJOS (B)

#### B1: print() statements innecesarios (~20+ en total)
- **Archivos**: Múltiples
- **Impacto**: Ruido en logs, potencial leak.

#### B2: Color constants repetidos en cada widget
- **Archivos**: `productos_screen.dart:66-68`, `product_form_modal.dart:90-97`, `product_list_item_card.dart`
- **Problema**: Los mismos colores fuchsia se definen en 3+ lugares.
- **Impacto**: Mantenimiento difícil.

#### B3: _buildFAB() es stub vacío
- **Archivo**: `product_form_modal.dart:586`
- **Problema**: `Widget _buildFAB() => SizedBox.shrink();` — dead code.

#### B4: _CategorySelectionDialog class no está definida en product_form_modal.dart
- **Archivo**: `product_form_modal.dart:832`
- **Problema**: `_CategorySelectionDialog` se referencia pero no está definida en el archivo. Probablemente está en otro archivo o es dead reference.

---

## RESUMEN DE IMPACTO

| Severidad | Count | Impacto |
|---|---|---|
| Crítico (C) | 4 | Performance degradation, data integrity |
| Alto (H) | 7 | Funcionalidad rota, code smells |
| Medio (M) | 12 | Mantenimiento, potenciales bugs |
| Bajo (B) | 4 | Code cleanliness |
| **TOTAL** | **27** | |

---

## PRIORIDAD DE FIX

1. **C1**: Eliminar `_fetchAllData()` post-CRUD → usar respuesta del POST
2. **C4 + H1**: Agregar debounce a búsqueda
3. **C2**: Eliminar `_loadDraft()` duplicado
4. **H2 + H3**: Completar funcionalidad de imprimir/trladar o marcar como stubs
5. **H4**: Eliminar print() statements
6. **M8**: Pasar copias immutable de categorías/proveedores
7. **M12**: Agregar null check en _loadDraft()
8. **H5 + H6 + H7**: Eliminar código muerto

---

## FIXES APLICADOS

(Se documentarán en PRODUCTS_FRONTEND_OPTIMIZATION.md después de cada fix)
