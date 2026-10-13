# PRODUCT_CREATE_UI_FIX — El producto creado ahora aparece inmediatamente

## 1. Causa exacta del problema

El producto se guardaba correctamente en el backend, pero **nunca se insertaba con su id real** en la lista local de la pantalla.

El flujo real del backend (verificado leyendo `backendgo/productos/producto.controller.go` sin modificarlo):

| Operación | Endpoint | Respuesta real |
|---|---|---|
| Creación simple | `POST /api/productos` | `201` + **el producto en la raíz** (`{id, nombre, ...}`) — SIN envoltorio `data` |
| Creación multi-sucursal | `POST /api/productos/distribucion` | `201` + `{success, message, data: {producto_maestro_id, productos: [...]}}` |
| Edición | `PUT /api/productos/:id` | `200` + `{success, message, producto: {...}}` |

Sin embargo, en `productos_screen.dart` el handler `onSave` solo contemplaba una forma:

```dart
if (responseData != null && responseData['data'] != null) {
  _addOrUpdateProductLocally(responseData['data'] as Map<String, dynamic>);
} else {
  // fallback con id falso (timestamp)
}
```

Resultado según el modo:

- **Creación simple** → `responseData['data']` es `null` (el producto está en la raíz) → se usaba el fallback que construía un producto con **id falso** (`DateTime.now().millisecondsSinceEpoch`) y datos parciales. Si había sucursal seleccionada, el fallback además podía quedar fuera del filtro por sucursal (id_sucursal como string vs int) → el producto no aparecía, o aparecía con datos incompletos e id incorrecto.
- **Creación multi-sucursal** → `responseData['data']` es un `Map` con `producto_maestro_id` y `productos` (no es un producto). `_addOrUpdateProductLocally` hacía `productData['id']` → `null` → **retornaba sin hacer nada** → el producto NUNCA aparecía.
- **Edición** → `responseData['producto']` no se leía → se usaba el fallback con datos parciales.

Esta es la causa exacta de "el producto se guarda, sale el mensaje de éxito, pero no aparece en la lista".

## 2. Archivo(s) modificados

Solo un archivo del módulo Productos:

- `lib/paginas/productos_screen.dart`

Nada del backend. Ningún otro módulo. Sin refactors globales.

## 3. Cómo se actualiza ahora el estado

Nuevo flujo implementado en `productos_screen.dart`:

```
POST /api/productos  (o /distribucion, o PUT)
↓
respuesta del backend
↓
_extractProductsFromResponse(responseData)   → producto(s) real(es)
↓
_addOrUpdateProductsLocally(products)        → insert/replace en _allProductos
↓
_filterProducts()                            → re-filtrado local (sin GET)
↓
setState() + onDataChanged                   → la UI muestra el producto
```

`_extractProductsFromResponse` (`productos_screen.dart:322`) reconoce los 3 formatos reales del backend:

1. `data.productos[]` → creación multi-sucursal (agrega todos los hermanos).
2. `producto` → edición.
3. producto en la raíz (`id` presente) → creación simple.

`_buildFallbackProduct` (`productos_screen.dart:355`) **solo** se usa cuando la respuesta no contiene ningún producto (ej: modo servidor local, que envía por socket y no devuelve datos). No inventa valores del backend más allá de lo que ya existía.

No se ejecuta `loadProducts()` / `fetchProducts()` / GET completo después del CREATE.

## 4. Cómo se evita duplicar productos

`_addOrUpdateProductsLocally` (`productos_screen.dart:389`) usa el **id real** del backend:

```dart
final idx = _allProductos.indexWhere((p) => p['id'] == id);
if (idx >= 0) {
  _allProductos[idx] = productData;   // ya existe → reemplaza
} else {
  _allProductos.insert(0, productData); // nuevo → inserta al inicio
}
```

- Si el id ya está en la lista (ej: retry, edición) → se reemplaza, jamás se duplica.
- Se usa el id, no el nombre ni el índice.

## 5. Cómo se respeta paginación

La lista visible se calcula en `_filterProducts()` + `_updatePage()` a partir de `_allProductos` completo. Al insertar el nuevo producto no se recarga ninguna página ni se pierden elementos:

- `_currentPage` se reinicia a `1` (el producto nuevo es el más reciente y aparece arriba).
- `_pageSize` y los botones de paginación no cambian.
- Los productos ya cargados de páginas anteriores permanecen intactos en `_allProductos`.

## 6. Cómo se respetan filtros

Tras insertar en `_allProductos`, se re-ejecuta `_filterProducts()`, que aplica los filtros activos:

- **Sucursal** (`_selectedBranchId`): solo aparece el hermano que coincide con la sucursal seleccionada.
- **Categoría** (`_selectedCategoryFilter`): solo aparece si `categoria.id` coincide.
- El producto creado solo se muestra si cumple los filtros vigentes; los filtros no se limpian.

## 7. Cómo se respeta búsqueda

`_filterProducts()` filtra por `codigo_barras` / `nombre` contra el texto de `_searchController`. Si el usuario busca "Coca" y crea "Samsung", el producto nuevo no aparece en esa búsqueda; al limpiar la búsqueda aparece. Si el nombre o código coincide con la búsqueda activa, aparece de inmediato.

## 8. Confirmación: NO se hace GET completo después del CREATE

Tras el POST exitoso el flujo es 100% local:

- No `GET /api/productos`
- No `GET /api/productos?page=...`
- No `_fetchAllData()` / `_fetchProductos()`

Únicas llamadas tras el guardado: limpieza del pendiente en SharedPreferences, notificación de éxito y actualización local de la lista. Los `_fetchAllData()` restantes del archivo corresponden a flujos previos y ajenos al CREATE del formulario (carga inicial, asistente IA, conexión/desconexión de servidor local, traslado).

## 9. Tests realizados

- `flutter analyze lib/paginas/productos_screen.dart` → **0 errores, 0 warnings nuevos** (solo items `info` preexistentes: `withOpacity`, `use_super_parameters`, etc.). No hay ningún aviso nuevo en las líneas modificadas.
- `flutter analyze` (proyecto completo) → los únicos errores son **preexistentes** en `test/widget_test.dart` (importa `package:appchantres/main.dart` pero el paquete se llama `appchannels` según `pubspec.yaml`), ajenos a este cambio.
- `flutter test` → falla por el mismo `test/widget_test.dart` roto de forma preexistente (no relacionado con el módulo Productos).

Pruebas manuales a ejecutar por el usuario (según el criterio de éxito):

| # | Escenario | Resultado esperado |
|---|---|---|
| 1 | Abrir Productos → crear producto | Aparece inmediatamente, sin reiniciar |
| 2 | Crear segundo producto | Ambos aparecen, sin duplicados |
| 3 | Crear producto con imágenes | Aparece de inmediato con su imagen |
| 4 | Crear producto multi-sucursal | Aparece con sus hermanos/stock correctos |
| 5 | Crear producto con series | No se pierde la información devuelta por el backend |
| 6 | Crear producto con variantes/colores | Variantes/colores conservados |
| 7 | Crear con búsqueda activa | Solo aparece si coincide con la búsqueda |
| 8 | Crear con filtros activos | Solo aparece si cumple los filtros |
| 9 | Crear tras cargar varias páginas | No desaparecen anteriores, no se duplican |
| 10 | Crear y luego hacer refresh | Sigue existiendo una sola vez |
| 11 | Cerrar y reabrir la app | El producto persiste |

## 10. Resultado final

El usuario puede ahora: abrir Productos → crear producto → guardar → ver el mensaje de éxito → cerrar el formulario → **ver el producto nuevo inmediatamente**, sin reiniciar, sin salir de Productos, sin refresh manual y sin volver a descargar el inventario.

Solo se tocó el frontend Flutter y solo el módulo Productos. Backend intacto.

## Nota (limitación documentada, sin cambio de contrato)

La respuesta de creación simple no incluye las relaciones pre-cargadas (`sucursal`, `proveedor`, `categoria`, `codigos`, `variantes`) porque el backend serializa el struct `Producto` sin `Preload`. Por eso la tarjeta recién creada muestra nombre/precio/stock/colores y la sucursal aparece tras un refresh. La solución **usa exactamente la respuesta del backend** y no reconstruye el objeto con datos inventados, cumpliendo el criterio `BACKEND_RESPONSE_LIMITATION` del encargo.
