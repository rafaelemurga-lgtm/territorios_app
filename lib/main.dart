import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // En web, evita que salga el menú del navegador al hacer clic derecho.
  if (kIsWeb) BrowserContextMenu.disableContextMenu();
  runApp(const MyApp());
}

/// Máximo de marcas permitidas por territorio.
const int maxMarcas = 30;

/// Colores de pin disponibles: nombre -> archivo en assets.
const Map<String, String> pinsPorColor = {
  'rojo': 'assets/pin.png',
  'azul': 'assets/pin_azul.png',
  'morado': 'assets/pin_morado.png',
};
const String colorPorDefecto = 'rojo';

// ---------------------------------------------------------------------------
// PALETA DE COLORES
// ---------------------------------------------------------------------------

class Paleta {
  static const Color marino = Color(0xFF2C405B); // azul oscuro
  static const Color acero = Color(0xFF688AB0); // azul medio
  static const Color grisAzulado = Color(0xFFD1DBE5); // gris azulado claro
  static const Color blancoAzulado = Color(0xFFF7F8FC); // casi blanco
  static const Color celeste = Color(0xFF7DBCDF); // azul cielo
}

// ---------------------------------------------------------------------------
// MODELOS
// ---------------------------------------------------------------------------

class Territorio {
  final int id;
  final String nombre;
  final String imagen; // ruta del asset

  const Territorio(this.id, this.nombre, this.imagen);
}

/// Territorios disponibles. Para agregar más, añade otra línea con
/// un id único, el nombre a mostrar y la imagen del mapa.
const List<Territorio> territorios = [
  Territorio(1, 'Territorio 1 - Cruce', 'assets/mapas/territorio_1.jpg'),
];

class Marca {
  final String id;
  final double dx; // posición relativa 0..1 (independiente del tamaño)
  final double dy;
  final String nota;
  final String color; // clave de pinsPorColor

  Marca({
    required this.id,
    required this.dx,
    required this.dy,
    required this.nota,
    this.color = colorPorDefecto,
  });

  String get asset => pinsPorColor[color] ?? pinsPorColor[colorPorDefecto]!;

  Map<String, dynamic> toJson() =>
      {'id': id, 'dx': dx, 'dy': dy, 'nota': nota, 'color': color};

  factory Marca.fromJson(Map<String, dynamic> j) => Marca(
        id: j['id'] as String,
        dx: (j['dx'] as num).toDouble(),
        dy: (j['dy'] as num).toDouble(),
        nota: j['nota'] as String,
        // Las marcas guardadas antes de esta versión no tienen color.
        color: (j['color'] as String?) ?? colorPorDefecto,
      );
}

/// Datos de registro de un territorio.
class Registro {
  DateTime? inicio;
  DateTime? fin;
  String encargado;

  Registro({this.inicio, this.fin, this.encargado = ''});

  Map<String, dynamic> toJson() => {
        'inicio': inicio?.toIso8601String(),
        'fin': fin?.toIso8601String(),
        'encargado': encargado,
      };

  factory Registro.fromJson(Map<String, dynamic> j) => Registro(
        inicio: j['inicio'] == null ? null : DateTime.parse(j['inicio'] as String),
        fin: j['fin'] == null ? null : DateTime.parse(j['fin'] as String),
        encargado: (j['encargado'] as String?) ?? '',
      );
}

/// Rango permitido para las fechas del registro.
final DateTime fechaMinima = DateTime(2026, 1, 1);
final DateTime fechaMaxima = DateTime(2030, 12, 31);

String formatearFecha(DateTime? d) => d == null
    ? ''
    : '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

// ---------------------------------------------------------------------------
// APP
// ---------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Territorios La isla, pocomchí',
      debugShowCheckedModeBanner: false,
      // Español para el calendario y los diálogos del sistema.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Paleta.blancoAzulado,
        colorScheme: const ColorScheme.light(
          primary: Paleta.marino,
          onPrimary: Paleta.blancoAzulado,
          primaryContainer: Paleta.grisAzulado,
          onPrimaryContainer: Paleta.marino,
          secondary: Paleta.acero,
          onSecondary: Paleta.blancoAzulado,
          secondaryContainer: Paleta.grisAzulado,
          onSecondaryContainer: Paleta.marino,
          tertiary: Paleta.celeste,
          onTertiary: Paleta.marino,
          surface: Paleta.blancoAzulado,
          onSurface: Paleta.marino,
          surfaceTint: Colors.transparent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Paleta.marino,
          foregroundColor: Paleta.blancoAzulado,
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Paleta.blancoAzulado,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Paleta.blancoAzulado,
          surfaceTintColor: Colors.transparent,
        ),
        dividerColor: Paleta.grisAzulado,
      ),
      home: const HomePage(),
    );
  }
}

// ---------------------------------------------------------------------------
// PÁGINA PRINCIPAL
// ---------------------------------------------------------------------------

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Territorios')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: territorios.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final t = territorios[i];
          return SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MapaPage(territorio: t)),
              ),
              child: Text(t.nombre, style: const TextStyle(fontSize: 18)),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PANTALLA DEL MAPA
// ---------------------------------------------------------------------------

class MapaPage extends StatefulWidget {
  final Territorio territorio;
  const MapaPage({super.key, required this.territorio});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  final PhotoViewController _controller = PhotoViewController();
  Size? _tamanoImagen;
  List<Marca> _marcas = [];
  Registro _registro = Registro();

  String get _clave => 'marcas_territorio_${widget.territorio.id}';

  @override
  void initState() {
    super.initState();
    _cargarTamanoImagen();
    _cargarMarcas();
    _cargarRegistro();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Obtiene el tamaño real de la imagen para posicionar las marcas sobre ella.
  void _cargarTamanoImagen() {
    final stream = AssetImage(widget.territorio.imagen)
        .resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      if (mounted) {
        setState(() => _tamanoImagen = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            ));
      }
      stream.removeListener(listener);
    }, onError: (e, _) {
      debugPrint('Error cargando imagen: $e');
    });
    stream.addListener(listener);
  }

  // ----------------------------- Persistencia ------------------------------

  Future<void> _cargarMarcas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_clave);
    if (raw == null) return;
    final lista = (jsonDecode(raw) as List)
        .map((e) => Marca.fromJson(e as Map<String, dynamic>))
        .toList();
    if (mounted) setState(() => _marcas = lista);
  }

  Future<void> _guardarMarcas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clave,
      jsonEncode(_marcas.map((m) => m.toJson()).toList()),
    );
  }

  // ------------------------------- Acciones --------------------------------

  bool _menuAbierto = false;

  Future<void> _mostrarMenu(Offset global, Offset local) async {
    if (_menuAbierto) return; // evita abrir dos menús a la vez
    _menuAbierto = true;
    try {
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox;
      final seleccion = await showMenu<String>(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromLTWH(global.dx, global.dy, 0, 0),
          Offset.zero & overlay.size,
        ),
        items: [
          PopupMenuItem(
            value: 'add',
            enabled: _marcas.length < maxMarcas,
            child: Text(
              _marcas.length < maxMarcas
                  ? 'Añadir Marca'
                  : 'Límite de $maxMarcas marcas alcanzado',
            ),
          ),
        ],
      );
      if (seleccion == 'add' && mounted) await _anadirMarca(local);
    } catch (e, st) {
      debugPrint('Error en menú de marcas: $e\n$st');
    } finally {
      _menuAbierto = false;
    }
  }

  Future<void> _anadirMarca(Offset local) async {
    if (_marcas.length >= maxMarcas) return;
    final size = _tamanoImagen!;
    final r = await _pedirNota();
    if (r == null) return;
    setState(() {
      _marcas.add(Marca(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        dx: (local.dx / size.width).clamp(0.0, 1.0),
        dy: (local.dy / size.height).clamp(0.0, 1.0),
        nota: r.nota,
        color: r.color,
      ));
    });
    await _guardarMarcas();
  }

  Future<({String nota, String color})?> _pedirNota() {
    final textoCtrl = TextEditingController();
    String colorElegido = colorPorDefecto;
    return showDialog<({String nota, String color})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Nueva marca'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textoCtrl,
                  autofocus: true,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Escribe una nota...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Color del pin'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: pinsPorColor.entries.map((e) {
                    final elegido = e.key == colorElegido;
                    return GestureDetector(
                      onTap: () => setStateDialog(() => colorElegido = e.key),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            width: 2,
                            color: elegido
                                ? Theme.of(ctx).colorScheme.primary
                                : Colors.transparent,
                          ),
                          color: elegido
                              ? Theme.of(ctx).colorScheme.primary.withOpacity(0.1)
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 56,
                              width: 32,
                              child: Image.asset(
                                e.value,
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomCenter,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              e.key[0].toUpperCase() + e.key.substring(1),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final t = textoCtrl.text.trim();
                if (t.isEmpty) return;
                Navigator.pop(ctx, (nota: t, color: colorElegido));
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verMarca(Marca m) async {
    final borrar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marca'),
        content: Text(m.nota),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (borrar == true) {
      setState(() => _marcas.removeWhere((x) => x.id == m.id));
      await _guardarMarcas();
    }
  }

  // --------------------------------- UI ------------------------------------

  // --------------------------- Lista de marcas -----------------------------

  /// Mueve el mapa para dejar la marca en el centro del visor.
  void _centrarEn(Marca m) {
    final img = _tamanoImagen;
    final s = _controller.scale;
    if (img == null || s == null) return;
    final rel = Offset(
      m.dx * img.width - img.width / 2,
      m.dy * img.height - img.height / 2,
    );
    final r = _controller.rotation;
    final c = math.cos(r), sn = math.sin(r);
    final rot = Offset(rel.dx * c - rel.dy * sn, rel.dx * sn + rel.dy * c);
    _controller.position = -rot * s;
  }

  Future<bool> _confirmarEliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar marca'),
        content: const Text('¿Seguro que quieres eliminar esta marca?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _abrirListaMarcas() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Marcas de ${widget.territorio.nombre} '
                    '(${_marcas.length}/$maxMarcas)',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                if (_marcas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aún no has creado marcas en este territorio.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _marcas.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final m = _marcas[i];
                        return ListTile(
                          leading: SizedBox(
                            width: 32,
                            height: 48,
                            child: Image.asset(
                              m.asset,
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                            ),
                          ),
                          title: Text(
                            m.nota,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Tocar la marca cierra la ventana y la centra en el mapa.
                          onTap: () {
                            Navigator.pop(ctx);
                            _centrarEn(m);
                          },
                          trailing: IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (!await _confirmarEliminar()) return;
                              setState(() => _marcas.removeWhere((x) => x.id == m.id));
                              await _guardarMarcas();
                              setSheet(() {});
                            },
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------- Registro --------------------------------

  String get _claveRegistro => 'registro_territorio_${widget.territorio.id}';

  Future<void> _cargarRegistro() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_claveRegistro);
    if (raw == null) return;
    try {
      final r = Registro.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (mounted) setState(() => _registro = r);
    } catch (e) {
      debugPrint('Error leyendo registro: $e');
    }
  }

  Future<void> _guardarRegistro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveRegistro, jsonEncode(_registro.toJson()));
  }

  Future<void> _abrirRegistro() async {
    DateTime? inicio = _registro.inicio;
    DateTime? fin = _registro.fin;
    final inicioCtrl = TextEditingController(text: formatearFecha(inicio));
    final finCtrl = TextEditingController(text: formatearFecha(fin));
    final encargadoCtrl = TextEditingController(text: _registro.encargado);

    Future<DateTime?> elegir(BuildContext ctx, DateTime? actual, DateTime minimo) {
      var inicial = actual ?? DateTime.now();
      if (inicial.isBefore(minimo)) inicial = minimo;
      if (inicial.isAfter(fechaMaxima)) inicial = fechaMaxima;
      return showDatePicker(
        context: ctx,
        initialDate: inicial,
        firstDate: minimo,
        lastDate: fechaMaxima,
      );
    }

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Registro de ${widget.territorio.nombre}'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: inicioCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Fecha de inicio de territorio',
                      border: const OutlineInputBorder(),
                      suffixIcon: inicio == null
                          ? const Icon(Icons.calendar_month)
                          : IconButton(
                              tooltip: 'Borrar fecha',
                              icon: const Icon(Icons.clear),
                              onPressed: () => setDialog(() {
                                inicio = null;
                                inicioCtrl.clear();
                              }),
                            ),
                    ),
                    onTap: () async {
                      final f = await elegir(ctx, inicio, fechaMinima);
                      if (f == null) return;
                      setDialog(() {
                        inicio = f;
                        inicioCtrl.text = formatearFecha(f);
                        // La fecha final no puede ser anterior a la inicial.
                        if (fin != null && fin!.isBefore(f)) {
                          fin = null;
                          finCtrl.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: finCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Fecha de territorio terminado',
                      border: const OutlineInputBorder(),
                      suffixIcon: fin == null
                          ? const Icon(Icons.calendar_month)
                          : IconButton(
                              tooltip: 'Borrar fecha',
                              icon: const Icon(Icons.clear),
                              onPressed: () => setDialog(() {
                                fin = null;
                                finCtrl.clear();
                              }),
                            ),
                    ),
                    onTap: () async {
                      final f = await elegir(ctx, fin, inicio ?? fechaMinima);
                      if (f == null) return;
                      setDialog(() {
                        fin = f;
                        finCtrl.text = formatearFecha(f);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: encargadoCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Encargado del grupo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (guardar == true) {
      setState(() {
        _registro = Registro(
          inicio: inicio,
          fin: fin,
          encargado: encargadoCtrl.text.trim(),
        );
      });
      await _guardarRegistro();
    }
  }

  // ---------------------------- Notificaciones -----------------------------

  void _abrirNotificaciones() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notificaciones'),
        // TODO: aquí irá el contenido de las notificaciones.
        content: const Text('No hay notificaciones por ahora.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Territorios La isla, pocomchí',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _abrirNotificaciones,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                // ---- Número y nombre del territorio ----
                _Recuadro(
                  child: Text(
                    widget.territorio.nombre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // ---- Fecha de inicio del territorio ----
                _Recuadro(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Fecha de inicio de territorio',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _registro.inicio == null
                            ? 'Sin fecha'
                            : formatearFecha(_registro.inicio),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tamanoImagen == null
                ? const Center(child: CircularProgressIndicator())
                : ClipRect(child: _construirMapa(_tamanoImagen!)),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Paleta.marino,
        surfaceTintColor: Colors.transparent,
        height: 64,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BarraItem(
              icono: Icons.home,
              etiqueta: 'Inicio',
              onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
            ),
            _BarraItem(
              icono: Icons.location_on,
              etiqueta: 'Marcas',
              onTap: _abrirListaMarcas,
            ),
            _BarraItem(
              icono: Icons.edit_note,
              etiqueta: 'Registro',
              onTap: _abrirRegistro,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------- Conversión pantalla <-> imagen -----------------------
  // PhotoView centra la imagen en el visor y le aplica:
  // trasladar(position) -> escalar(scale) -> rotar(rotation) alrededor del centro.

  Offset? _imagenAPantalla(Offset p, Size visor, Size img, PhotoViewControllerValue v) {
    final s = v.scale;
    if (s == null || s <= 0) return null;
    final rel = p - Offset(img.width / 2, img.height / 2);
    final c = math.cos(v.rotation), sn = math.sin(v.rotation);
    final rot = Offset(rel.dx * c - rel.dy * sn, rel.dx * sn + rel.dy * c);
    return Offset(visor.width / 2, visor.height / 2) + v.position + rot * s;
  }

  Offset? _pantallaAImagen(Offset q, Size visor, Size img, PhotoViewControllerValue v) {
    final s = v.scale;
    if (s == null || s <= 0) return null;
    final rel = (q - Offset(visor.width / 2, visor.height / 2) - v.position) / s;
    final c = math.cos(v.rotation), sn = math.sin(v.rotation);
    final inv = Offset(rel.dx * c + rel.dy * sn, -rel.dx * sn + rel.dy * c);
    return inv + Offset(img.width / 2, img.height / 2);
  }

  void _menuEn(Offset global, Offset localVisor, Size visor, Size img) {
    final p = _pantallaAImagen(localVisor, visor, img, _controller.value);
    if (p == null) return;
    // Solo se permiten marcas dentro de la imagen.
    if (p.dx < 0 || p.dy < 0 || p.dx > img.width || p.dy > img.height) return;
    _mostrarMenu(global, p);
  }

  Widget _construirMapa(Size img) {
    return LayoutBuilder(builder: (context, constraints) {
      final visor = Size(constraints.maxWidth, constraints.maxHeight);
      return Listener(
        behavior: HitTestBehavior.translucent,
        // Mouse: botón derecho
        onPointerDown: (e) {
          if (e.kind == PointerDeviceKind.mouse &&
              e.buttons == kSecondaryMouseButton) {
            _menuEn(e.position, e.localPosition, visor, img);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          // Dedo: mantener presionado
          onLongPressStart: (d) =>
              _menuEn(d.globalPosition, d.localPosition, visor, img),
          child: Stack(
            children: [
              Positioned.fill(
                child: PhotoView(
                  controller: _controller,
                  imageProvider: AssetImage(widget.territorio.imagen),
                  enableRotation: true,
                  minScale: PhotoViewComputedScale.contained * 0.5,
                  maxScale: PhotoViewComputedScale.covered * 8,
                  initialScale: PhotoViewComputedScale.contained,
                  backgroundDecoration:
                      const BoxDecoration(color: Paleta.grisAzulado),
                ),
              ),
              // Pines dibujados en coordenadas de pantalla: siempre derechos,
              // con tamaño constante y tocables en cualquier parte del mapa.
              Positioned.fill(
                child: StreamBuilder<PhotoViewControllerValue>(
                  stream: _controller.outputStateStream,
                  initialData: _controller.value,
                  builder: (context, snap) {
                    final v = snap.data!;
                    const alto = 56.0;
                    const ancho = alto * 120 / 256;
                    final pines = <Widget>[];
                    for (final m in _marcas) {
                      final pt = _imagenAPantalla(
                        Offset(m.dx * img.width, m.dy * img.height),
                        visor,
                        img,
                        v,
                      );
                      if (pt == null) continue;
                      pines.add(Positioned(
                        left: pt.dx - ancho / 2,
                        top: pt.dy - alto, // la punta queda en el punto
                        width: ancho,
                        height: alto,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _verMarca(m),
                          child: Image.asset(
                            m.asset,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ));
                    }
                    return Stack(clipBehavior: Clip.none, children: pines);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// ITEM DE LA BARRA INFERIOR
// ---------------------------------------------------------------------------

class _BarraItem extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;

  const _BarraItem({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 26, color: Paleta.celeste),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              style: const TextStyle(fontSize: 12, color: Paleta.blancoAzulado),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RECUADRO CON ESQUINAS REDONDEADAS
// ---------------------------------------------------------------------------

class _Recuadro extends StatelessWidget {
  final Widget child;
  const _Recuadro({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Paleta.grisAzulado,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Paleta.acero),
      ),
      child: Center(child: child),
    );
  }
}